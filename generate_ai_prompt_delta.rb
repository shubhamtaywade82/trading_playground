#!/usr/bin/env ruby
# frozen_string_literal: true

# AI analysis for Delta Exchange **perpetuals** (BTCUSD, ETHUSD, etc.) — the tradable futures.
# We do not trade or analyse spot; spot/index is shown only as reference for the underlying.
# Fetches perpetual ticker (mark, funding, OI) + perpetual OHLC, builds prompt, calls AI, optional Telegram.
#
# Setup: No credentials needed for market data. DELTA_API_KEY / DELTA_API_SECRET only for trading.
#        AI: AI_PROVIDER=openai or ollama. Loop: LOOP_INTERVAL=300
# Run:   ruby generate_ai_prompt_delta.rb

require 'dotenv'
Dotenv.load(File.expand_path('.env', __dir__))

require_relative 'lib/delta_exchange_client'
require_relative 'lib/technical_indicators'
require_relative 'lib/smc'
require_relative 'lib/ai_caller'
require_relative 'lib/telegram_notifier'

# Timeframe: candle resolution (Delta: 1m, 3m, 5m, 15m, 30m, 1h, 2h, 4h, 6h, 1d, 1w) and lookback in minutes
DELTA_RESOLUTION = ENV.fetch('DELTA_RESOLUTION', '5m')
INTRADAY_MINUTES = ENV.fetch('DELTA_LOOKBACK_MINUTES', '60').to_i
SMA_PERIOD       = 20
RSI_PERIOD       = 14

def delta_symbols
  raw = ENV.fetch('DELTA_SYMBOLS', nil)
  list = raw&.split(',')&.map(&:strip)&.reject(&:empty?)
  list&.any? ? list : %w[BTCUSD ETHUSD]
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

def build_ai_prompt_delta(symbol, data)
  funding_pct = (data[:funding_rate].to_f * 100).round(4)
  smc_line = data[:smc_summary] || '—'
  <<~PROMPT
    #{symbol} perpetual (futures) on Delta Exchange — analyse for trading the perpetual, not spot. Data: Mark #{format_num(data[:mark_price])} | Index #{format_num(data[:spot_price])} (ref) | Funding #{funding_pct}% | OI #{data[:oi]} | RSI #{format_num(data[:rsi_14])} | Trend #{data[:trend]} | Chg 24h #{data[:mark_change_24h]}%. SMC: #{smc_line}.

    Reply in 2–4 lines only. Format:
    • Bias: Long | Short | No trade
    • Reason: (one short line)
    • Action: (optional: level or wait)
  PROMPT
end

MAX_VERDICT_LEN = 280

def format_summary_delta(symbol, data, ai_response)
  funding_pct = (data[:funding_rate].to_f * 100).round(4)
  smc = data[:smc_summary].to_s.slice(0, 50)
  line1 = "#{symbol} perp  Mark #{format_num(data[:mark_price])}  Index #{format_num(data[:spot_price])}  Funding #{funding_pct}%  RSI #{format_num(data[:rsi_14])}  #{data[:trend]}  SMC #{smc}"
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

  summary = format_summary_delta(symbol, data, ai_response)
  puts "\n#{summary}"

  return unless ENV['TELEGRAM_CHAT_ID']

  begin
    TelegramNotifier.send_message(summary)
  rescue StandardError => e
    warn "Telegram send failed: #{e.message}"
  end
end

def run_cycle_for(symbol)
  client = DeltaExchangeClient.new
  ticker_resp = client.ticker(symbol)
  result = ticker_resp.is_a?(Hash) ? (ticker_resp['result'] || ticker_resp) : {}
  raise "Ticker failed for #{symbol}" if result.empty?

  mark_price   = (result['mark_price'] || result[:mark_price]).to_f
  spot_price   = (result['spot_price'] || result[:spot_price]).to_f
  funding_rate = result['funding_rate'] || result[:funding_rate] || 0
  oi           = result['oi'] || result[:oi] || result['oi_contracts'] || '—'
  mark_change  = result['mark_change_24h'] || result[:mark_change_24h] || '—'

  end_ts   = Time.now.to_i
  start_ts = end_ts - (INTRADAY_MINUTES * 60)
  candles_resp = client.candles(symbol: symbol, resolution: DELTA_RESOLUTION, start_ts: start_ts, end_ts: end_ts)
  candle_list = candles_resp.is_a?(Hash) ? candles_resp['result'] : nil
  candle_list = Array(candle_list || [])
  closes = candle_list.filter_map { |c| (c['close'] || c[:close])&.to_f }
  opens = candle_list.filter_map { |c| (c['open'] || c[:open])&.to_f }
  highs = candle_list.filter_map { |c| (c['high'] || c[:high])&.to_f }
  lows  = candle_list.filter_map { |c| (c['low'] || c[:low])&.to_f }

  sma_20 = TechnicalIndicators.sma(closes, SMA_PERIOD)
  rsi_14 = TechnicalIndicators.rsi(closes, RSI_PERIOD)
  # Trend from perpetual mark vs SMA(perpetual closes) — we trade the perpetual, not spot
  trend  = trend_label(mark_price, sma_20)
  smc_summary = SMC.summary(opens, highs, lows, closes, mark_price)

  data = {
    mark_price: mark_price,
    spot_price: spot_price,
    funding_rate: funding_rate,
    oi: oi,
    sma_20: sma_20,
    rsi_14: rsi_14,
    trend: trend,
    mark_change_24h: mark_change,
    smc_summary: smc_summary
  }
  prompt = build_ai_prompt_delta(symbol, data)
  print_and_call_ai(symbol, prompt, data)
end

def run_cycle
  puts "Timestamp: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} (Delta Exchange)"
  delta_symbols.each do |symbol|
    run_cycle_for(symbol)
  rescue StandardError => e
    warn "Error for #{symbol}: #{e.message}"
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
