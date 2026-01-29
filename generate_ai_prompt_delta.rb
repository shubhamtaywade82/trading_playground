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

require_relative 'lib/delta/client'
require_relative 'lib/delta/format_report'
require_relative 'lib/delta/action_logger'
require_relative 'lib/delta/system_prompts'
require_relative 'lib/delta/analysis'
require_relative 'lib/candle'
require_relative 'lib/candle_series'
require_relative 'lib/pattern_summary'
require_relative 'lib/technical_indicators'
require_relative 'lib/smc'
require_relative 'lib/ai_caller'
require_relative 'lib/telegram_notifier'

# Timeframe: 5m for LT and key levels; 1h for HTF bias. Need enough 5m candles for SMA(20), RSI(14), ATR(14).
DELTA_RESOLUTION   = ENV.fetch('DELTA_RESOLUTION', '5m')
INTRADAY_MINUTES   = ENV.fetch('DELTA_LOOKBACK_MINUTES', '120').to_i
HTF_RESOLUTION     = '1h'
HTF_LOOKBACK_HOURS = ENV.fetch('DELTA_HTF_LOOKBACK_HOURS', '24').to_i
SMA_PERIOD         = 20
RSI_PERIOD         = 14
ATR_PERIOD         = 14

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

def format_levels(arr)
  arr.is_a?(Array) && arr.any? ? arr.map { |x| format_num(x) }.join(', ') : '—'
end

def delta_candle_list_to_candles(list)
  return [] unless list.is_a?(Array) && list.any?

  list.filter_map do |c|
    close = (c['close'] || c[:close])&.to_f
    next unless close

    Candle.new(
      timestamp: c['time'] || c['timestamp'] || c[:time] || c[:timestamp],
      open: (c['open'] || c[:open]).to_f,
      high: (c['high'] || c[:high]).to_f,
      low: (c['low'] || c[:low]).to_f,
      close: close,
      volume: (c['volume'] || c[:volume] || 0).to_f
    )
  end
end

def delta_pattern_summary(client, symbol, end_ts, candle_list, list_1h)
  start_ts = end_ts - (INTRADAY_MINUTES * 60)
  start_ts_1h = end_ts - (HTF_LOOKBACK_HOURS * 3600)
  candles_5m  = delta_candle_list_to_candles(candle_list)
  candles_60m = delta_candle_list_to_candles(list_1h)
  return 'Pattern: None' if candles_5m.size < 5

  candles_15m = delta_candle_list_to_candles(
    (client.candles(symbol: symbol, resolution: '15m', start_ts: start_ts, end_ts: end_ts).dig('result') || [])
  )
  candles_1m = delta_candle_list_to_candles(
    (client.candles(symbol: symbol, resolution: '1m', start_ts: start_ts, end_ts: end_ts).dig('result') || [])
  )
  context = {
    candles_60m: candles_60m,
    candles_15m: candles_15m,
    candles_5m: candles_5m,
    candles_1m: candles_1m,
    support_level: nil,
    resistance_level: nil
  }
  PatternSummary.call(context)
rescue StandardError
  'Pattern: None'
end

def build_ai_prompt_delta(symbol, data)
  funding_pct = (data[:funding_rate].to_f * 100).round(4)
  levels = data[:key_levels] || {}
  res = format_levels(levels[:resistance])
  sup = format_levels(levels[:support])
  atr_pct = data[:atr_pct]
  htf = data[:htf_trend]
  funding_reg = data[:funding_regime] || '—'
  ob = data[:orderbook_imbalance]

  sections = []
  sections << "#{symbol} perpetual (futures) on Delta Exchange. Analyse for trading the perpetual, not spot."
  sections << "Market: Mark #{format_num(data[:mark_price])} | Index #{format_num(data[:spot_price])} (ref) | OI #{data[:oi]} | Chg 24h #{data[:mark_change_24h]}%"
  sections << "LT (5m): RSI #{format_num(data[:rsi_14])} | SMA(20) #{format_num(data[:sma_20])} | Trend #{data[:trend]}"
  sections << "HTF (1h): #{htf || '—'} (structure: #{data[:htf_structure] || '—'})"
  sections << "Key levels — Resistance: #{res} | Support: #{sup}"
  sections << "Funding: #{funding_pct}% (#{funding_reg})"
  sections << "Volatility: ATR #{format_num(data[:atr])} (#{atr_pct}% of price)" if atr_pct
  sections << "Orderbook: bid share #{ob[:imbalance_ratio]}" if ob && ob[:imbalance_ratio]
  sections << "SMC: #{data[:smc_summary] || '—'}"
  sections << (data[:pattern_summary] || 'Pattern: None')

  prompt = sections.join("\n")
  prompt += "\n\nReply in 2–4 lines. Format:\n• Bias: Long | Short | No trade\n• Reason: (one short line)\n• Action: (optional: level or wait)"
  prompt
end

def print_and_call_ai(symbol, ai_prompt, data)
  ai_response = nil
  ai_provider = ENV['AI_PROVIDER']&.strip&.downcase
  if ai_provider && %w[openai ollama].include?(ai_provider)
    ai_response = AiCaller.call(ai_prompt, provider: ai_provider, model: ENV.fetch('AI_MODEL', nil),
                                system_prompt: Delta::SystemPrompts::DELTA_FUTURES_SYSTEM_PROMPT)
  end

  puts FormatDeltaReport.format_console(symbol, data, ai_response)

  DeltaActionLogger.log(symbol, data, ai_response)

  return unless ENV['TELEGRAM_CHAT_ID']

  begin
    TelegramNotifier.send_message(FormatDeltaReport.format_telegram(symbol, data, ai_response))
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
  start_ts_1h = end_ts - (HTF_LOOKBACK_HOURS * 3600)

  candles_resp = client.candles(symbol: symbol, resolution: DELTA_RESOLUTION, start_ts: start_ts, end_ts: end_ts)
  candle_list = candles_resp.is_a?(Hash) ? candles_resp['result'] : nil
  candle_list = Array(candle_list || [])
  closes = candle_list.filter_map { |c| (c['close'] || c[:close])&.to_f }
  opens = candle_list.filter_map { |c| (c['open'] || c[:open])&.to_f }
  highs = candle_list.filter_map { |c| (c['high'] || c[:high])&.to_f }
  lows  = candle_list.filter_map { |c| (c['low'] || c[:low])&.to_f }

  candles_1h_resp = client.candles(symbol: symbol, resolution: HTF_RESOLUTION, start_ts: start_ts_1h, end_ts: end_ts)
  list_1h = candles_1h_resp.is_a?(Hash) ? candles_1h_resp['result'] : nil
  list_1h = Array(list_1h || [])
  closes_1h = list_1h.filter_map { |c| (c['close'] || c[:close])&.to_f }
  highs_1h = list_1h.filter_map { |c| (c['high'] || c[:high])&.to_f }
  lows_1h  = list_1h.filter_map { |c| (c['low'] || c[:low])&.to_f }
  sma_1h = TechnicalIndicators.sma(closes_1h, SMA_PERIOD)
  last_close_1h = closes_1h.last
  htf_trend = Delta::Analysis.htf_trend_label(last_close_1h, sma_1h)
  htf_structure = SMC.structure_label(highs_1h, lows_1h)

  orderbook_resp = begin
    client.orderbook(symbol, depth: 20)
  rescue StandardError
    nil
  end
  orderbook_imbalance = Delta::Analysis.orderbook_imbalance(orderbook_resp)

  sma_20 = TechnicalIndicators.sma(closes, SMA_PERIOD)
  rsi_14 = TechnicalIndicators.rsi(closes, RSI_PERIOD)
  trend  = trend_label(mark_price, sma_20)
  atr    = TechnicalIndicators.atr(highs, lows, closes, ATR_PERIOD)
  atr_ctx = Delta::Analysis.atr_context(atr, mark_price)
  smc_summary = SMC.summary_with_components(opens, highs, lows, closes, mark_price)
  key_levels = Delta::Analysis.key_levels(highs, lows)
  funding_regime = Delta::Analysis.funding_regime(funding_rate)
  pattern_summary = delta_pattern_summary(client, symbol, end_ts, candle_list, list_1h)

  data = {
    mark_price: mark_price,
    spot_price: spot_price,
    funding_rate: funding_rate,
    oi: oi,
    sma_20: sma_20,
    rsi_14: rsi_14,
    trend: trend,
    mark_change_24h: mark_change,
    smc_summary: smc_summary,
    key_levels: key_levels,
    funding_regime: funding_regime,
    atr: atr_ctx[:atr],
    atr_pct: atr_ctx[:atr_pct],
    htf_trend: htf_trend,
    htf_structure: htf_structure,
    orderbook_imbalance: orderbook_imbalance,
    pattern_summary: pattern_summary
  }
  prompt = build_ai_prompt_delta(symbol, data)
  print_and_call_ai(symbol, prompt, data)
end

def run_cycle
  puts "\n  ═════════════════════════════════════════════"
  puts "  Delta Exchange · #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
  puts '  ═════════════════════════════════════════════'
  delta_symbols.each do |symbol|
    run_cycle_for(symbol)
  rescue StandardError => e
    warn "Error for #{symbol}: #{e.message}"
  end
  puts "\n  End of cycle\n\n"
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
