#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates an AI prompt with live NIFTY and/or SENSEX data: PCR, OHLC, intraday 5m,
# SMA/RSI, SMC, key levels. Focus: options buying only — buy CE when bullish, buy PE when bearish (PCR trend reversal).
# Run during market hours.
#
# Setup: export DHAN_CLIENT_ID=... DHAN_ACCESS_TOKEN=...
#        (or CLIENT_ID / ACCESS_TOKEN — gem uses these)
# Optional AI: export AI_PROVIDER=openai (or ollama), OPENAI_API_KEY=... for OpenAI;
#              or AI_PROVIDER=ollama with local Ollama (OLLAMA_HOST, OLLAMA_MODEL).
# Loop:  export LOOP_INTERVAL=300 to run every 5 minutes (errors in a cycle don't exit).
# Mock:  MOCK_DATA=1 uses fake market data (no Dhan API); AI still runs if AI_PROVIDER set.
# Log:   Verdict + context written to log/dhan_ai_actions.jsonl (disable with DHAN_LOG_ACTIONS=0).
# Skills: When .cursor/skills/intraday-options/ exists, its Hard Rules + Output are appended to the system prompt.
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
require_relative 'lib/smc'
require_relative 'lib/candle'
require_relative 'lib/candle_series'
require_relative 'lib/pattern_summary'
require_relative 'lib/ai_caller'
require_relative 'lib/indicator_helpers'
require_relative 'lib/dhan/option_chain_metrics'
require_relative 'lib/dhan/ohlc_normalizer'
require_relative 'lib/dhan/key_levels'
require_relative 'lib/dhan/strike_suggestions'
require_relative 'lib/dhan/prompt_builder'
require_relative 'lib/dhan/format_report'
require_relative 'lib/dhan/action_logger'
require_relative 'lib/intraday_options_skills'
require_relative 'lib/telegram_notifier'
require_relative 'lib/mock_market_data' if MOCK_MODE

unless MOCK_MODE
  require 'dhan_hq'
  DhanHQ.configure_with_env
end

# --- Config (both indices use exchange_segment 'IDX_I') ---
EXCHANGE_SEGMENT   = 'IDX_I'
INTRADAY_MINUTES   = 60
SMA_PERIOD         = 20
RSI_PERIOD         = 14
# Intraday range: from_date < to_date; up to 5 days in one request (Dhan allows multi-day intraday).
DHAN_INTRADAY_DAYS = ENV.fetch('DHAN_INTRADAY_DAYS', '5').to_i.clamp(1, 90)

# System prompt so the model thinks as NIFTY/SENSEX options-buying analyst, not generic.
DHAN_OPTIONS_SYSTEM_PROMPT_BASE = <<~TEXT.strip.freeze
  You are an options analyst focused only on NIFTY and SENSEX index options for intraday trading.
  Strategy: options buying only — buy CE when bullish, buy PE when bearish. No option selling.
  Use PCR, RSI, trend (vs SMA), SMC structure, and key levels together; prefer "No trade" when signals conflict or are weak.
  The prompt includes suggested strikes (CE/PE symbols) and hold-until (expiry or EOD). When suggesting a trade, you may reference specific strikes from the list and the hold-until guidance in your Action.
  Reply in 2–4 lines: Bias (Buy CE / Buy PE / No trade), Reason (one short line), Action (level or wait; optionally mention strike and hold until). Do not give generic market commentary; stick to this strategy and the data provided.
TEXT

def dhan_system_prompt
  guardrails = IntradayOptionsSkills.guardrails_for_prompt(root: __dir__)
  return DHAN_OPTIONS_SYSTEM_PROMPT_BASE if guardrails.to_s.strip.empty?

  "#{DHAN_OPTIONS_SYSTEM_PROMPT_BASE}\n\n#{guardrails}"
end

def underlyings
  raw = ENV.fetch('UNDERLYINGS', nil)
  list = raw&.split(',')&.map(&:strip)&.reject(&:empty?)
  return list if list&.any?

  single = ENV.fetch('UNDERLYING', nil)&.strip
  single ? [single] : %w[NIFTY SENSEX]
end

def dhan_intraday_range
  to_date = Date.today
  from_date = to_date - DHAN_INTRADAY_DAYS
  [from_date.to_s, to_date.to_s]
end

def dhan_pattern_summary(inst, from_date, to_date, ohlc_5m, _symbol)
  candles_5m = CandleSeries.from_ohlcv_arrays(
    opens: ohlc_5m[:opens], highs: ohlc_5m[:highs], lows: ohlc_5m[:lows], closes: ohlc_5m[:closes]
  )
  return 'Pattern: None' if candles_5m.size < 5

  candles_60m = []
  candles_15m = []
  candles_1m  = []
  [['60', candles_60m], ['15', candles_15m], ['1', candles_1m]].each do |interval, store|
    raw = inst.intraday(from_date: from_date, to_date: to_date, interval: interval)
    arr = Dhan::OhlcNormalizer.from_response(raw)
    next if arr[:closes].size < 5

    store.concat(CandleSeries.from_ohlcv_arrays(
      opens: arr[:opens], highs: arr[:highs], lows: arr[:lows], closes: arr[:closes]
    ))
  end

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

def trend_label(spot, sma)
  IndicatorHelpers.trend_label(spot, sma)
end

def print_guardrails_if_loaded
  guardrails = IntradayOptionsSkills.guardrails_for_prompt(root: __dir__)
  return if guardrails.to_s.strip.empty?

  puts "  ────────────────────────────────────────────"
  puts "  System prompt guardrails (intraday-options skills)"
  puts "  ────────────────────────────────────────────"
  guardrails.each_line { |line| puts "  #{line.rstrip}" }
  puts ""
end

def print_and_call_ai(symbol, ai_prompt, data)
  ai_response = nil
  ai_provider = ENV['AI_PROVIDER']&.strip&.downcase
  if ai_provider && %w[openai ollama].include?(ai_provider)
    ai_response = AiCaller.call(ai_prompt, provider: ai_provider, model: ENV.fetch('AI_MODEL', nil), system_prompt: dhan_system_prompt)
  end

  puts FormatDhanReport.format_console(symbol, data, ai_response)

  DhanActionLogger.log(symbol, data, ai_response)

  return unless ENV['TELEGRAM_CHAT_ID']

  begin
    TelegramNotifier.send_message(FormatDhanReport.format_telegram(symbol, data, ai_response))
  rescue StandardError => e
    warn "Telegram send failed: #{e.message}"
  end
end

def run_cycle_for(symbol)
  inst = DhanHQ::Models::Instrument.find(EXCHANGE_SEGMENT, symbol)
  raise "Instrument not found: #{EXCHANGE_SEGMENT} / #{symbol}" if inst.nil?

  spot_price, current_ohlc_str = spot_and_ohlc_str(inst.ohlc)
  nearest_expiry = nearest_expiry_for(inst.expiry_list)
  oc_metrics, spot_price, oc = option_chain_metrics_for(inst, nearest_expiry, spot_price)
  strike_suggestions = Dhan::StrikeSuggestions.suggest(oc, spot_price, nearest_expiry, symbol)

  from_date, to_date = dhan_intraday_range
  ohlc_5m = Dhan::OhlcNormalizer.from_response(inst.intraday(from_date: from_date, to_date: to_date, interval: '5'))
  ohlc_15m = Dhan::OhlcNormalizer.from_response(inst.intraday(from_date: from_date, to_date: to_date, interval: '15'))
  closes_5m = ohlc_5m[:closes]

  sma_20 = TechnicalIndicators.sma(closes_5m, SMA_PERIOD)
  rsi_14 = TechnicalIndicators.rsi(closes_5m, RSI_PERIOD)
  trend = trend_label(spot_price, sma_20)
  last_change = last_change_pct(closes_5m)
  smc_summary = SMC.summary_with_components(
    ohlc_15m[:opens], ohlc_15m[:highs], ohlc_15m[:lows], ohlc_15m[:closes], spot_price
  )
  key_levels = Dhan::KeyLevels.from_ohlc(ohlc_15m[:highs], ohlc_15m[:lows])
  pattern_summary = dhan_pattern_summary(inst, from_date, to_date, ohlc_5m, symbol)

  data = build_cycle_data(
    spot_price: spot_price, current_ohlc_str: current_ohlc_str, nearest_expiry: nearest_expiry,
    oc_metrics: oc_metrics, strike_suggestions: strike_suggestions,
    sma_20: sma_20, rsi_14: rsi_14, trend: trend, last_change: last_change,
    smc_summary: smc_summary, key_levels: key_levels, pattern_summary: pattern_summary
  )
  print_and_call_ai(symbol, Dhan::PromptBuilder.build(symbol, data), data)
end

def spot_and_ohlc_str(ohlc)
  spot = 0.0
  ohlc_str = 'N/A'
  return [spot, ohlc_str] unless ohlc.is_a?(Hash)

  spot = (ohlc['last_price'] || ohlc[:last_price] || ohlc['close'] || ohlc[:close]).to_f
  o, h, l, c = ohlc['open'] || ohlc[:open], ohlc['high'] || ohlc[:high], ohlc['low'] || ohlc[:low], ohlc['close'] || ohlc[:close]
  ohlc_str = "#{o}/#{h}/#{l}/#{c}" if o && h && l && c
  [spot, ohlc_str]
end

def nearest_expiry_for(expiries)
  list = Array(expiries)
  list.filter_map { |e| Date.parse(e.to_s) rescue nil }
      .select { |d| d >= Date.today }.min&.to_s
end

def option_chain_metrics_for(inst, nearest_expiry, spot_price)
  default = { call_oi: 0, put_oi: 0, atm_iv_ce: nil, atm_iv_pe: nil, total_volume: 0 }
  return [default, spot_price, nil] unless nearest_expiry

  last_price, oc = Dhan::OptionChainMetrics.extract(inst.option_chain(expiry: nearest_expiry))
  spot = (last_price && spot_price.zero? ? last_price.to_f : spot_price)
  metrics = oc.is_a?(Hash) ? Dhan::OptionChainMetrics.metrics(oc, spot) : default
  [metrics, spot, oc]
end

def last_change_pct(closes)
  return 'N/A' if closes.size < 2 || closes[-2].to_f.zero?
  ((closes.last - closes[-2]) / closes[-2] * 100).round(2)
end

def build_cycle_data(spot_price:, current_ohlc_str:, nearest_expiry:, oc_metrics:, strike_suggestions:, sma_20:, rsi_14:, trend:, last_change:, smc_summary:, key_levels:, pattern_summary:)
  {
    spot_price: spot_price,
    current_ohlc_str: current_ohlc_str,
    nearest_expiry: nearest_expiry,
    call_oi: oc_metrics[:call_oi],
    put_oi: oc_metrics[:put_oi],
    atm_iv_ce: oc_metrics[:atm_iv_ce],
    atm_iv_pe: oc_metrics[:atm_iv_pe],
    total_volume: oc_metrics[:total_volume],
    strike_suggestions: strike_suggestions,
    sma_20: sma_20,
    rsi_14: rsi_14,
    trend: trend,
    last_change: last_change,
    smc_summary: smc_summary,
    key_levels: key_levels,
    pattern_summary: pattern_summary
  }
end

def run_cycle_mock(symbol)
  data = MockMarketData.data(symbol)
  print_and_call_ai(symbol, Dhan::PromptBuilder.build(symbol, data), data)
end

def run_cycle
  ts = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  puts "\n  ═════════════════════════════════════════════"
  puts "  Dhan · #{ts}"
  puts "  ═════════════════════════════════════════════"
  if MOCK_MODE
    puts "  (Mock data — no Dhan API)\n"
  end
  print_guardrails_if_loaded
  underlyings.each do |symbol|
    MOCK_MODE ? run_cycle_mock(symbol) : run_cycle_for(symbol)
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
