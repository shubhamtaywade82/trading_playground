#!/usr/bin/env ruby
# frozen_string_literal: true

# Reads log/dhan_ai_actions.jsonl and checks whether suggested levels were hit by spot in the
# next 2–3 log entries (same symbol), not by current spot.
# Usage: ruby verify_dhan_actions.rb [--last N] [--since YYYY-MM-DD] [--hours H] [--next K] [--ai]
#   --last N     verify last N log entries (default: 20)
#   --since DATE entries on or after DATE
#   --hours H    entries in last H hours
#   --next K     use next K entries (same symbol) to check levels (default: 3)
#   --no-fetch   unused; kept for compatibility (verification uses only log data)
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
  opts = { last: 20, fetch: true, ai: false, next_n: 3 }
  args = ARGV.dup
  while (arg = args.shift)
    case arg
    when '--last'     then opts[:last] = args.shift.to_i
    when '--since'   then opts[:since] = args.shift
    when '--hours'   then opts[:hours] = args.shift.to_f
    when '--next'    then opts[:next_n] = args.shift.to_i.clamp(1, 10)
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

# Next N entries for the same symbol after index (chronological order). Returns array of spot_price.
def next_spots_for(entries, index, symbol, n)
  return [] if index.nil? || index < 0 || n < 1

  entries
    .each_with_index
    .select { |e, i| e['symbol'] == symbol && i > index && e['spot_price'] }
    .first(n)
    .map { |e, _| e['spot_price'].to_f }
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

def verify_one(entry, next_spots, next_n_label)
  spot_then = entry['spot_price']&.to_f
  levels = Array(entry['levels'])
  key_levels = entry['key_levels']
  bias = entry['bias']
  lines = []
  lines << "  At:    #{entry['at']}"
  next_str = next_spots.any? ? next_spots.map { |s| format_level(s) }.join(', ') : '—'
  lines << "  Symbol: #{entry['symbol']}  Spot then: #{spot_then}  #{next_n_label}: #{next_str}"
  lines << "  Bias:  #{bias || '—'}"
  lines << "  Reason: #{entry['reason'] || '—'}"
  lines << "  Action: #{entry['action'] || '—'}"

  if key_levels.is_a?(Hash) && next_spots.any?
    res = Array(key_levels['resistance'] || key_levels[:resistance])
    sup = Array(key_levels['support'] || key_levels[:support])
    max_next = next_spots.max
    min_next = next_spots.min
    if res.any? || sup.any?
      lines << '  Key levels (SMC):'
      res.each do |level|
        l = level.to_f
        status = max_next >= l ? '✓ broke above' : '— below'
        lines << "    R #{format_level(l)} → next max #{format_level(max_next)} #{status}"
      end
      sup.each do |level|
        l = level.to_f
        status = min_next <= l ? '✓ broke below' : '— above'
        lines << "    S #{format_level(l)} → next min #{format_level(min_next)} #{status}"
      end
    end
  end

  if levels.any? && next_spots.any?
    max_next = next_spots.max
    min_next = next_spots.min
    lines << '  Action levels:'
    levels.each do |level|
      l = level.to_f
      above = max_next >= l ? '✓' : '✗'
      below = min_next <= l ? '✓' : '✗'
      lines << "    #{format_level(l)} → next: any ≥? #{above}  any ≤? #{below}"
    end
  elsif levels.any?
    lines << "  Action levels: #{levels.map { |l| format_level(l) }.join(', ')} (no subsequent readings for this symbol)"
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
  next_n = opts[:next_n] || 3
  next_n_label = "Next #{next_n} spot"

  puts "\n  ═════════════════════════════════════════════"
  puts "  Dhan AI actions verification (#{entries.size} entries, check vs #{next_n_label})"
  puts "  ═════════════════════════════════════════════\n"

  stats = { action_entries: 0, action_entries_hit: 0, key_r_broken: 0, key_s_broken: 0 }
  report_lines = []
  entries.reverse_each.with_index do |entry, rev_i|
    chrono_index = entries.size - 1 - rev_i
    next_spots = next_spots_for(entries, chrono_index, entry['symbol'], next_n)
    update_verification_stats(stats, entry, next_spots)
    block = verify_one(entry, next_spots, next_n_label)
    report_lines << block
    puts block
    puts '  ' + ('─' * 44)
  end

  puts "\n  ═════════════════════════════════════════════"
  puts "  Verification summary (computed from log)"
  puts "  ═════════════════════════════════════════════"
  puts summary_bullets(stats, next_n)
  puts "\n"

  return unless opts[:ai] && report_lines.any?

  ai_provider = ENV['AI_PROVIDER']&.strip&.downcase
  if ai_provider && %w[openai ollama].include?(ai_provider)
    prompt = <<~PROMPT
      Verification stats (from Dhan AI action log, next #{next_n} spot readings):
      #{summary_bullets(stats, next_n)}

      Write one short paragraph (2–3 sentences) takeaway for the trader. Do not repeat the numbers; interpret them (e.g. "Action levels were hit often" or "No-trade was right to wait" or "Key levels held"). No preamble.
    PROMPT
    summary = AiCaller.call(prompt, provider: ai_provider, model: ENV.fetch('AI_MODEL', nil))
    puts '  ═════════════════════════════════════════════'
    puts '  AI takeaway'
    puts "  ═════════════════════════════════════════════\n\n  #{summary}\n\n"
  else
    warn '  --ai requires AI_PROVIDER=openai or ollama in .env'
  end
end

def update_verification_stats(stats, entry, next_spots)
  return if next_spots.empty?

  key_levels = entry['key_levels']
  if key_levels.is_a?(Hash)
    res = Array(key_levels['resistance'] || key_levels[:resistance]).map { |x| x.to_f }
    sup = Array(key_levels['support'] || key_levels[:support]).map { |x| x.to_f }
    max_next = next_spots.max
    min_next = next_spots.min
    stats[:key_r_broken] += res.count { |r| max_next >= r }
    stats[:key_s_broken] += sup.count { |s| min_next <= s }
  end

  levels = Array(entry['levels']).map { |x| x.to_f }
  return if levels.empty?

  stats[:action_entries] += 1
  max_next = next_spots.max
  min_next = next_spots.min
  any_hit = levels.any? { |l| max_next >= l || min_next <= l }
  stats[:action_entries_hit] += 1 if any_hit
end

def summary_bullets(stats, next_n)
  lines = []
  lines << "  1. Entries with action levels hit (in next #{next_n} spot): #{stats[:action_entries_hit]} of #{stats[:action_entries]}"
  lines << "  2. Key levels broken in next readings: R broke above #{stats[:key_r_broken]}, S broke below #{stats[:key_s_broken]}"
  total_key = stats[:key_r_broken] + stats[:key_s_broken]
  lines << "  3. Key levels: #{total_key} R/S levels were broken by spot in the next #{next_n} readings."
  takeaway = if stats[:action_entries].positive?
    pct = (100.0 * stats[:action_entries_hit] / stats[:action_entries]).round(0)
    "  4. Takeaway: #{stats[:action_entries_hit]} of #{stats[:action_entries]} entries with action levels (#{pct}%) had at least one level hit in the next #{next_n} readings."
  else
    "  4. Takeaway: No entries with action levels and subsequent readings to check."
  end
  lines << takeaway
  lines.join("\n")
end

run(parse_args)
