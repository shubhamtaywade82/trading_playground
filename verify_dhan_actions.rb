#!/usr/bin/env ruby
# frozen_string_literal: true

# Reads log/dhan_ai_actions.jsonl and checks whether suggested levels were hit by current spot.
# Usage: ruby verify_dhan_actions.rb [--last N] [--since YYYY-MM-DD] [--hours H] [--ai]
#   --last N     verify last N log entries (default: 20)
#   --since DATE entries on or after DATE
#   --hours H    entries in last H hours
#   --no-fetch   do not fetch current spot from Dhan; only print log entries
#   --ai         after report, send it to AI (OpenAI/Ollama) for a short summary; needs AI_PROVIDER

require 'dotenv'
Dotenv.load(File.expand_path('.env', __dir__))

ENV['CLIENT_ID']    ||= ENV.fetch('DHAN_CLIENT_ID', nil)
ENV['ACCESS_TOKEN'] ||= ENV.fetch('DHAN_ACCESS_TOKEN', nil)

require 'json'
require 'time'
require 'date'
require_relative 'lib/dhan/option_chain_metrics'
require_relative 'lib/ai_caller'

LOG_PATH = File.join(__dir__, 'log', 'dhan_ai_actions.jsonl')
EXCHANGE_SEGMENT = 'IDX_I'

def parse_args
  opts = { last: 20, fetch: true, ai: false }
  args = ARGV.dup
  while (arg = args.shift)
    case arg
    when '--last'     then opts[:last] = args.shift.to_i
    when '--since'   then opts[:since] = args.shift
    when '--hours'   then opts[:hours] = args.shift.to_f
    when '--no-fetch' then opts[:fetch] = false
    when '--ai'      then opts[:ai] = true
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

def current_spots(symbols)
  require 'dhan_hq'
  DhanHQ.configure_with_env
  symbols.to_h do |s|
    inst = DhanHQ::Models::Instrument.find(EXCHANGE_SEGMENT, s)
    spot = nil
    if inst
      chain = nil
      expiries = Array(inst.expiry_list)
      nearest = expiries.filter_map { |e| Date.parse(e.to_s) rescue nil }.select { |d| d >= Date.today }.min&.to_s
      if nearest
        chain = inst.option_chain(expiry: nearest)
        last_price, = Dhan::OptionChainMetrics.extract(chain)
        spot = last_price.to_f if last_price
      end
      spot ||= (inst.ohlc.is_a?(Hash) && (inst.ohlc['last_price'] || inst.ohlc['close']))&.to_f
    end
    [s, spot]
  end
rescue LoadError, StandardError => e
  warn "Could not fetch current spot from Dhan: #{e.message}"
  {}
end

def format_level(level)
  level.is_a?(Numeric) ? level.round(2) : level
end

def verify_one(entry, spot_now)
  spot_then = entry['spot_price']&.to_f
  levels = Array(entry['levels'])
  key_levels = entry['key_levels']
  bias = entry['bias']
  lines = []
  lines << "  At:    #{entry['at']}"
  lines << "  Symbol: #{entry['symbol']}  Spot then: #{spot_then}  Spot now: #{spot_now || '—'}"
  lines << "  Bias:  #{bias || '—'}"
  lines << "  Reason: #{entry['reason'] || '—'}"
  lines << "  Action: #{entry['action'] || '—'}"

  if key_levels.is_a?(Hash) && spot_now
    res = Array(key_levels['resistance'] || key_levels[:resistance])
    sup = Array(key_levels['support'] || key_levels[:support])
    if res.any? || sup.any?
      lines << '  Key levels (SMC):'
      res.each do |level|
        l = level.to_f
        status = spot_now >= l ? '✓ broke above' : '— below'
        lines << "    R #{format_level(l)} → now #{spot_now.round(2)} #{status}"
      end
      sup.each do |level|
        l = level.to_f
        status = spot_now <= l ? '✓ broke below' : '— above'
        lines << "    S #{format_level(l)} → now #{spot_now.round(2)} #{status}"
      end
    end
  end

  if levels.any? && spot_now
    lines << '  Action levels:'
    levels.each do |level|
      above = spot_now >= level
      status = above ? '✓ price above' : '✗ price below'
      lines << "    #{format_level(level)} → now #{spot_now.round(2)} #{status}"
    end
  elsif levels.any?
    lines << "  Action levels: #{levels.map { |l| format_level(l) }.join(', ')} (no current spot)"
  end
  lines.join("\n")
end

def run(opts)
  entries = read_log(LOG_PATH)
  if entries.empty?
    puts "No log entries in #{LOG_PATH}. Run generate_ai_prompt.rb with AI_PROVIDER set first."
    return
  end

  entries = filter_entries(entries, opts)

  symbols = entries.map { |e| e['symbol'] }.uniq
  spots = opts[:fetch] ? current_spots(symbols) : {}

  puts "\n  ═════════════════════════════════════════════"
  puts "  Dhan AI actions verification (#{entries.size} entries)"
  puts "  ═════════════════════════════════════════════\n"

  report_lines = []
  entries.reverse_each do |entry|
    spot_now = spots[entry['symbol']]
    block = verify_one(entry, spot_now)
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
      Below is a verification report of Dhan (NIFTY/SENSEX) AI suggestions: bias/action, suggested levels, and (when present) key SMC levels (resistance R / support S) at log time. For each entry we compare current spot to those levels (broke above/below). Summarise in 3–5 short lines: which levels were hit, which were not, and one takeaway (e.g. how many calls were right so far).

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
