#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates an AI prompt with live NIFTY and/or SENSEX data (PCR, OHLC, intraday, indicators)
# for the PCR Trend Reversal strategy. Run during market hours.
#
# Setup: export DHAN_CLIENT_ID=... DHAN_ACCESS_TOKEN=...
#        (or CLIENT_ID / ACCESS_TOKEN — gem uses these)
# Optional AI: export AI_PROVIDER=openai (or ollama), OPENAI_API_KEY=... for OpenAI;
#              or AI_PROVIDER=ollama with local Ollama (OLLAMA_HOST, OLLAMA_MODEL).
# Loop:  export LOOP_INTERVAL=300 to run every 5 minutes (errors in a cycle don't exit).
# Mock:  MOCK_DATA=1 uses fake market data (no Dhan API); AI still runs if AI_PROVIDER set.
# Run:   ruby generate_ai_prompt.rb
#
# Env:   Loads .env from the script directory if present (via dotenv gem).

require 'dotenv'
Dotenv.load(File.expand_path('.env', __dir__))

MOCK_MODE = ENV['MOCK_DATA'].to_s.strip == '1' || ENV['MOCK'].to_s.strip == '1'

ENV['CLIENT_ID']    ||= ENV.fetch('DHAN_CLIENT_ID', nil)
ENV['ACCESS_TOKEN'] ||= ENV.fetch('DHAN_ACCESS_TOKEN', nil)

require 'date'
require_relative 'lib/technical_indicators'
require_relative 'lib/ai_caller'
require_relative 'lib/telegram_notifier'
require_relative 'lib/mock_market_data' if MOCK_MODE

unless MOCK_MODE
  require 'dhan_hq'
  DhanHQ.configure_with_env
end

# --- Config (both indices use exchange_segment 'IDX_I') ---
EXCHANGE_SEGMENT  = 'IDX_I'
INTRADAY_MINUTES  = 60
SMA_PERIOD        = 20
RSI_PERIOD        = 14

def underlyings
  raw = ENV.fetch('UNDERLYINGS', nil)
  list = raw&.split(',')&.map(&:strip)&.reject(&:empty?)
  return list if list&.any?

  single = ENV.fetch('UNDERLYING', nil)&.strip
  single ? [single] : %w[NIFTY SENSEX]
end

def extract_oc_and_last_price(option_chain_response)
  raw = option_chain_response
  data = raw.is_a?(Hash) ? (raw['data'] || raw) : raw
  return [nil, nil, nil] unless data

  last_price = data['last_price'] || data[:last_price]
  oc = data['oc'] || data[:oc]
  [last_price, oc, data]
end

def sum_oi(oc, side)
  return 0 unless oc.is_a?(Hash)

  key = side == :call ? 'ce' : 'pe'
  oc.sum do |_strike, row|
    next 0 unless row.is_a?(Hash)

    leg = row[key] || row[key.to_sym]
    (leg && (leg['oi'] || leg[:oi])).to_i
  end
end

def fetch_closes(intraday_response)
  return [] unless intraday_response.is_a?(Array)

  intraday_response.map { |c| c.is_a?(Hash) ? (c['close'] || c[:close]) : nil }.compact.map(&:to_f)
end

def trend_label(spot, sma)
  return 'Neutral' if sma.nil?
  return 'Bullish (above SMA)' if spot > sma
  return 'Bearish (below SMA)' if spot < sma

  'Neutral'
end

def format_num(value)
  value.is_a?(Numeric) ? value.round(2) : value
end

def build_ai_prompt(symbol, data)
  pcr = data[:call_oi].positive? ? (data[:put_oi].to_f / data[:call_oi]) : 0.0
  <<~PROMPT
    #{symbol} options (PCR trend reversal, intraday). Data: Spot #{format_num(data[:spot_price])} | PCR #{format_num(pcr)} | RSI #{format_num(data[:rsi_14])} | Trend #{data[:trend]} | Chg #{data[:last_change]}%.

    Reply in 2–4 lines only. Format:
    • Bias: CE | PE | No trade
    • Reason: (one short line)
    • Action: (optional: level or wait)
  PROMPT
end

MAX_VERDICT_LEN = 280

def format_summary(symbol, data, ai_response)
  pcr = data[:call_oi].positive? ? (data[:put_oi].to_f / data[:call_oi]) : 0.0
  spot = format_num(data[:spot_price])
  rsi = format_num(data[:rsi_14])
  line1 = "#{symbol}  Spot #{spot}  PCR #{format_num(pcr)}  RSI #{rsi}  #{data[:trend]}"
  verdict = ai_response.to_s.strip.gsub(/\n+/, ' ').strip
  verdict = verdict.empty? ? '—' : verdict.slice(0, MAX_VERDICT_LEN)
  verdict += '…' if ai_response.to_s.length > MAX_VERDICT_LEN
  "#{line1}\n→ #{verdict}"
end

def print_and_call_ai(symbol, ai_prompt, data)
  ai_response = nil
  ai_provider = ENV['AI_PROVIDER']&.strip&.downcase
  if ai_provider && %w[openai ollama].include?(ai_provider)
    ai_response = AiCaller.call(ai_prompt, provider: ai_provider, model: ENV.fetch('AI_MODEL', nil))
  end

  summary = format_summary(symbol, data, ai_response)
  puts "\n#{summary}"

  return unless ENV['TELEGRAM_CHAT_ID']

  begin
    TelegramNotifier.send_message(summary)
  rescue StandardError => e
    warn "Telegram send failed: #{e.message}"
  end
end

def run_cycle_for(symbol)
  inst = DhanHQ::Models::Instrument.find(EXCHANGE_SEGMENT, symbol)
  raise "Instrument not found: #{EXCHANGE_SEGMENT} / #{symbol}" if inst.nil?

  ohlc = inst.ohlc
  spot_price = nil
  current_ohlc_str = 'N/A'
  if ohlc.is_a?(Hash)
    spot_price = (ohlc['last_price'] || ohlc[:last_price] || ohlc['close'] || ohlc[:close]).to_f
    o = ohlc['open'] || ohlc[:open]
    h = ohlc['high'] || ohlc[:high]
    l = ohlc['low'] || ohlc[:low]
    c = ohlc['close'] || ohlc[:close]
    current_ohlc_str = "#{o}/#{h}/#{l}/#{c}" if o && h && l && c
  end
  spot_price ||= 0.0

  expiries = inst.expiry_list
  expiries = Array(expiries) if expiries
  nearest_expiry = expiries
                   .filter_map do |e|
                     Date.parse(e.to_s)
                   rescue StandardError
                     nil
                   end
                   .select { |d| d >= Date.today }
                   .min
                   &.to_s

  call_oi = 0
  put_oi  = 0
  if nearest_expiry
    chain = inst.option_chain(expiry: nearest_expiry)
    last_price_from_chain, oc, = extract_oc_and_last_price(chain)
    spot_price = last_price_from_chain.to_f if last_price_from_chain && spot_price.zero?
    if oc.is_a?(Hash)
      call_oi = sum_oi(oc, :call)
      put_oi  = sum_oi(oc, :put)
    end
  end

  from_ts = (Time.now - (INTRADAY_MINUTES * 60)).strftime('%Y-%m-%d %H:%M:%S')
  to_ts   = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  intraday = inst.intraday(from_date: from_ts, to_date: to_ts, interval: '5')
  closes = fetch_closes(intraday)

  sma_20 = TechnicalIndicators.sma(closes, SMA_PERIOD)
  rsi_14 = TechnicalIndicators.rsi(closes, RSI_PERIOD)
  trend  = trend_label(spot_price, sma_20)

  last_change = if closes.size >= 2 && closes[-2].nonzero?
                  ((closes.last - closes[-2]) / closes[-2] * 100).round(2)
                else
                  'N/A'
                end

  data = {
    spot_price: spot_price,
    current_ohlc_str: current_ohlc_str,
    nearest_expiry: nearest_expiry,
    call_oi: call_oi,
    put_oi: put_oi,
    sma_20: sma_20,
    rsi_14: rsi_14,
    trend: trend,
    last_change: last_change
  }
  print_and_call_ai(symbol, build_ai_prompt(symbol, data), data)
end

def run_cycle_mock(symbol)
  data = MockMarketData.data(symbol)
  print_and_call_ai(symbol, build_ai_prompt(symbol, data), data)
end

def run_cycle
  puts "Timestamp: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
  if MOCK_MODE
    puts "(Mock data — no Dhan API)\n"
    underlyings.each { |symbol| run_cycle_mock(symbol) }
  else
    underlyings.each { |symbol| run_cycle_for(symbol) }
  end
  puts "\n--- End of Cycle ---\n"
end

loop_interval = ENV['LOOP_INTERVAL']&.strip&.to_i

if loop_interval&.positive?
  loop do
    begin
      run_cycle
    rescue StandardError => e
      warn "Error in cycle: #{e.message}"
    end
    sleep loop_interval
  end
else
  begin
    run_cycle
  rescue StandardError => e
    warn "Error: #{e.message}"
    exit 1
  end
end
