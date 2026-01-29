#!/usr/bin/env ruby
# frozen_string_literal: true

# Options-buying pattern engine: data → analysis → decision → execution.
# Load candles from data/candles/*.csv or pass in-memory. No globals.
#
# Usage:
#   ruby run_pattern_engine.rb
#   (requires data/candles/index_1m.csv, index_5m.csv, index_15m.csv, index_60m.csv)
#
# Or from code:
#   context = { candles_60m: ..., candles_15m: ..., candles_5m: ..., candles_1m: nil, iv_percentile: 50, dte: 3 }
#   result = ExecutionPipeline.call(context)

require 'dotenv'
Dotenv.load(File.expand_path('.env', __dir__))

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

symbol = ENV.fetch('PATTERN_SYMBOL', 'index')

candles_60m = CandleSeries.load(symbol, :m60)
candles_15m = CandleSeries.load(symbol, :m15)
candles_5m  = CandleSeries.load(symbol, :m5)
candles_1m  = CandleSeries.load(symbol, :m1)

if candles_60m.empty? || candles_15m.empty? || candles_5m.empty?
  puts "No candle data. Add CSV under data/candles/#{symbol}_1m.csv, _5m.csv, _15m.csv, _60m.csv"
  puts "Or wire CandleSeries.load to your fetcher (DhanHQ, Delta, etc.)."
  exit 0
end

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
  puts "Signal: #{result[:direction]} | pattern: #{result[:pattern]} | SL: #{result[:sl]} | TP: #{result[:tp]}"
else
  puts "No trade: volatility filter, trend/pattern mismatch, or no valid pattern."
end
