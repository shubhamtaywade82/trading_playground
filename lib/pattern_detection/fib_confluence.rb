# frozen_string_literal: true

require_relative 'candle_series'

# Fibonacci confluence only. Trade only if another pattern confirms.
# Key levels: 38.2%, 50%, 61.8%. Draw from swing low → swing high.
module PatternDetection
  class FibConfluence
    LEVELS = [0.382, 0.5, 0.618].freeze

    def initialize(candles_15m:, swing_low: nil, swing_high: nil)
      @candles_15m = candles_15m || []
      @swing_low = swing_low
      @swing_high = swing_high
    end

    # Returns { valid: true/false, reason:, levels: { 38.2 => price, 50 => price, 61.8 => price } }
    def levels_from_swing
      low = @swing_low
      high = @swing_high
      if low.nil? || high.nil?
        ohlcv = PatternDetection::CandleSeries.ohlcv(@candles_15m)
        lows = ohlcv[:lows]
        highs = ohlcv[:highs]
        return { valid: false, reason: 'No swing low/high', levels: {} } if lows.size < 2 || highs.size < 2
        low = lows.min
        high = highs.max
      end
      range = high - low
      lvls = LEVELS.map { |pct| [pct, (high - range * pct).round(4)] }.to_h
      { valid: true, reason: 'Fib levels from swing', levels: lvls }
    end

    # Check if price is near a fib level (within 0.5% of range).
    def price_at_level?(price, range)
      return false if range.nil? || range.zero?
      low = @swing_low
      high = @swing_high
      low ||= PatternDetection::CandleSeries.ohlcv(@candles_15m)[:lows].min
      high ||= PatternDetection::CandleSeries.ohlcv(@candles_15m)[:highs].max
      return false if low.nil? || high.nil?
      LEVELS.any? { |pct| (price - (high - range * pct)).abs / range < 0.005 }
    end
  end
end
