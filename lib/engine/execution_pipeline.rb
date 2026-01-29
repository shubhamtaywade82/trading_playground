# frozen_string_literal: true

require_relative '../market_context/trend_detector'
require_relative '../market_context/volatility_filter'
require_relative 'pattern_engine'
require_relative 'pattern_signal'
require_relative '../options/option_filters'

class ExecutionPipeline
  def self.call(context)
    return nil unless VolatilityFilter.allowed?(context[:candles_15m])

    trend = TrendDetector.call(context[:candles_60m])
    pattern = PatternEngine.run(context)
    return nil unless pattern

    return nil if trend == :bullish && pattern.direction == :bearish
    return nil if trend == :bearish && pattern.direction == :bullish

    return nil unless OptionFilters.allowed?(
      iv_percentile: context[:iv_percentile],
      dte: context[:dte]
    )

    sl = pattern.respond_to?(:signal) && pattern.signal ? pattern.signal[:sl] : nil
    tp = pattern.respond_to?(:signal) && pattern.signal ? pattern.signal[:tp] : nil

    PatternSignal.new(pattern.direction, pattern: pattern.class.name, sl: sl, tp: tp).execute
  end
end
