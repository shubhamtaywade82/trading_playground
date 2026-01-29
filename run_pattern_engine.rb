#!/usr/bin/env ruby
# frozen_string_literal: true

# Options-buying pattern engine: data → analysis → decision → execution.
# Candles: CSV (data/candles/*.csv) or API when CANDLE_SOURCE=dhan|delta.
#
# Usage:
#   ruby run_pattern_engine.rb
#   CSV: add data/candles/{PATTERN_SYMBOL}_1m.csv, _5m.csv, _15m.csv, _60m.csv
#   API: CANDLE_SOURCE=dhan PATTERN_SECURITY_ID=1333 (Dhan); or CANDLE_SOURCE=delta PATTERN_SYMBOL=BTCUSD (Delta India)
#
# Or from code:
#   context = { candles_60m: ..., candles_15m: ..., candles_5m: ..., candles_1m: nil, iv_percentile: 50, dte: 3 }
#   result = ExecutionPipeline.call(context)

require 'dotenv'
Dotenv.load(File.expand_path('.env', __dir__))
# Allow env from args: ruby run_pattern_engine.rb CANDLE_SOURCE=dhan PATTERN_SECURITY_ID=99926000
ARGV.each do |arg|
  next unless arg.include?('=') && !arg.start_with?('-')

  k, v = arg.split('=', 2)
  ENV[k] = v if k && !k.empty?
end

require_relative 'lib/candle'
require_relative 'lib/candle_series'
require_relative 'lib/indicators/atr'
require_relative 'lib/indicators/ema'
require_relative 'lib/indicators/rsi'
require_relative 'lib/indicators/volume_metrics'
require_relative 'lib/market_context/trend_detector'
require_relative 'lib/market_context/volatility_filter'
require_relative 'lib/patterns/base_pattern'
require_relative 'lib/patterns/swing_detector'
require_relative 'lib/patterns/head_and_shoulders'
require_relative 'lib/patterns/double_top_bottom'
require_relative 'lib/patterns/triangle'
require_relative 'lib/patterns/flag_pennant'
require_relative 'lib/patterns/engulfing'
require_relative 'lib/options/option_filters'
require_relative 'lib/options/strike_selector'
require_relative 'lib/engine/pattern_signal'
require_relative 'lib/engine/pattern_engine'
require_relative 'lib/engine/execution_pipeline'

# Multi-symbol: Dhan use PATTERN_SYMBOLS=NIFTY,SENSEX PATTERN_SECURITY_IDS=13,51; Delta use PATTERN_SYMBOLS=BTCUSD,ETHUSD
def symbol_pairs
  source = ENV['CANDLE_SOURCE']&.strip&.downcase
  symbols_str = ENV['PATTERN_SYMBOLS']&.strip
  ids_str = ENV['PATTERN_SECURITY_IDS']&.strip

  if source == 'dhan' && symbols_str && ids_str
    symbols = symbols_str.split(',').map(&:strip).reject(&:empty?)
    ids = ids_str.split(',').map(&:strip).reject(&:empty?)
    return symbols.zip(ids).reject { |s, i| s.nil? || s.empty? || i.nil? || i.empty? } if symbols.size == ids.size
  end

  if symbols_str
    symbols = symbols_str.split(',').map(&:strip).reject(&:empty?)
    return symbols.map { |s| [s, nil] } if symbols.any?
  end

  single = ENV.fetch('PATTERN_SYMBOL', 'index')
  [[single, ENV['PATTERN_SECURITY_ID']&.strip]]
end

def run_for_symbol(symbol, security_id)
  ENV['PATTERN_SECURITY_ID'] = security_id if security_id
  candles_60m = CandleSeries.load(symbol, :m60)
  candles_15m = CandleSeries.load(symbol, :m15)
  candles_5m  = CandleSeries.load(symbol, :m5)
  candles_1m  = CandleSeries.load(symbol, :m1)

  return false if candles_60m.empty? || candles_15m.empty? || candles_5m.empty?

  context = {
    candles_60m: candles_60m,
    candles_15m: candles_15m,
    candles_5m: candles_5m,
    candles_1m: candles_1m,
    iv_percentile: ENV['IV_PERCENTILE']&.to_f,
    dte: ENV['DTE']&.to_i,
    support_level: ENV['SUPPORT_LEVEL']&.to_f,
    resistance_level: ENV['RESISTANCE_LEVEL']&.to_f
  }
  result = ExecutionPipeline.call(context)
  if result
    puts "  #{symbol}: Signal #{result[:direction]} | pattern #{result[:pattern]} | SL: #{result[:sl]} | TP: #{result[:tp]}"
  else
    puts "  #{symbol}: No trade (volatility filter, trend/pattern mismatch, or no valid pattern)."
  end
  true
end

pairs = symbol_pairs
any_loaded = false
pairs.each do |symbol, security_id|
  any_loaded = true if run_for_symbol(symbol, security_id)
end

unless any_loaded
  symbol = pairs.first&.first || 'index'
  puts "No candle data. Add CSV under data/candles/#{symbol}_1m.csv, _5m.csv, _15m.csv, _60m.csv"
  puts "Or use API (set env vars before the command):"
  puts "  Delta (multi): CANDLE_SOURCE=delta PATTERN_SYMBOLS=BTCUSD,ETHUSD ruby run_pattern_engine.rb"
  puts "  Dhan (NIFTY+SENSEX): CANDLE_SOURCE=dhan PATTERN_SYMBOLS=NIFTY,SENSEX PATTERN_SECURITY_IDS=13,51 ruby run_pattern_engine.rb"
  puts "         Also set: PATTERN_EXCHANGE_SEGMENT=IDX_I PATTERN_INSTRUMENT=INDEX. Requires DHAN_CLIENT_ID and DHAN_ACCESS_TOKEN."
  exit 0
end
