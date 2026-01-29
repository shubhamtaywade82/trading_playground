#!/usr/bin/env ruby
# frozen_string_literal: true

# Reads log/delta_ai_actions.jsonl and checks whether suggested levels were hit by current price.
# Usage: ruby verify_delta_actions.rb [--last N] [--since YYYY-MM-DD] [--hours H] [--ai]
#   --last N     verify last N log entries (default: 20)
#   --since DATE entries on or after DATE
#   --hours H    entries in last H hours
#   --no-fetch   do not fetch current price; only print log entries
#   --ai         after report, send it to AI (OpenAI/Ollama) for a short summary; needs AI_PROVIDER

require 'dotenv'
Dotenv.load(File.expand_path('.env', __dir__))

require 'json'
require 'time'
require_relative 'lib/delta/client'
require_relative 'lib/ai_caller'

LOG_PATH = File.join(__dir__, 'log', 'delta_ai_actions.jsonl')

def parse_args
  opts = { last: 20, fetch: true, ai: false }
  args = ARGV.dup
  while (arg = args.shift)
    case arg
    when '--last'     then opts[:last] = args.shift.to_i
    when '--since'    then opts[:since] = args.shift
    when '--hours'    then opts[:hours] = args.shift.to_f
    when '--no-fetch' then opts[:fetch] = false
    when '--ai'       then opts[:ai] = true
    end
  end
  opts
end

def read_log(path)
  return [] unless File.file?(path)

  File.readlines(path, chomp: true).filter_map do |line|
    JSON.parse(line)
  rescue JSON::ParserError
    nil
  end
end

def filter_entries(entries, opts)
  if opts[:since]
    t = Time.parse("#{opts[:since]} 00:00:00 UTC")
    entries = entries.select { |e| Time.parse(e['at']) >= t }
  end
  if opts[:hours] && opts[:hours].positive?
    cutoff = Time.now.utc - (opts[:hours] * 3600)
    entries = entries.select { |e| Time.parse(e['at']) >= cutoff }
  end
  entries = entries.last(opts[:last]) if opts[:last].positive?
  entries
end

def current_marks(symbols)
  client = DeltaExchangeClient.new
  symbols.to_h { |s| [s, client.ticker(s).dig('result', 'mark_price')&.to_f] }
end

def verify_one(entry, mark_now)
  mark_then = entry['mark_price']&.to_f
  levels = Array(entry['levels'])
  bias = entry['bias']
  lines = []
  lines << "  At:    #{entry['at']}"
  lines << "  Symbol: #{entry['symbol']}  Mark then: #{mark_then}  Mark now: #{mark_now || '—'}"
  lines << "  Bias:  #{bias || '—'}"
  lines << "  Reason: #{entry['reason'] || '—'}"
  lines << "  Action: #{entry['action'] || '—'}"
  if levels.any? && mark_now
    lines << '  Levels:'
    levels.each do |level|
      above = mark_now >= level
      status = above ? '✓ price above' : '✗ price below'
      lines << "    #{level} → now #{mark_now.round(2)} #{status}"
    end
  elsif levels.any?
    lines << "  Levels: #{levels.join(', ')} (no current price)"
  end
  lines.join("\n")
end

def run(opts)
  entries = read_log(LOG_PATH)
  if entries.empty?
    puts "No log entries in #{LOG_PATH}. Run generate_ai_prompt_delta.rb with AI_PROVIDER set first."
    return
  end

  entries = filter_entries(entries, opts)
  entries = entries.last(opts[:last]) if opts[:last].positive?

  symbols = entries.map { |e| e['symbol'] }.uniq
  marks = opts[:fetch] ? current_marks(symbols) : {}

  puts "\n  ═════════════════════════════════════════════"
  puts "  Delta AI actions verification (#{entries.size} entries)"
  puts "  ═════════════════════════════════════════════\n"

  report_lines = []
  entries.reverse_each do |entry|
    mark_now = marks[entry['symbol']]
    block = verify_one(entry, mark_now)
    report_lines << block
    puts block
    puts '  ' + ('─' * 44)
  end
  puts "\n"

  return unless opts[:ai] && report_lines.any?

  ai_provider = ENV['AI_PROVIDER']&.strip&.downcase
  if ai_provider && %w[openai ollama].include?(ai_provider)
    report_text = report_lines.join("\n\n")
    prompt = <<~PROMPT
      Below is a verification report of Delta Exchange AI suggestions (suggested bias/action/levels vs current price). Summarise in 3–5 short lines: which suggested levels were hit (price above/below), which were not, and one takeaway (e.g. how many calls were right so far).

      Report:
      #{report_text}
    PROMPT
    summary = AiCaller.call(prompt, provider: ai_provider, model: ENV.fetch('AI_MODEL', nil))
    puts '  ═════════════════════════════════════════════'
    puts '  AI summary'
    puts "  ═════════════════════════════════════════════\n\n  #{summary}\n\n"
  else
    warn '  --ai requires AI_PROVIDER=openai or ollama in .env'
  end
end

run(parse_args)
