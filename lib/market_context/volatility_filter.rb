# frozen_string_literal: true

require_relative '../indicators/atr'

class VolatilityFilter
  def self.allowed?(candles_15m)
    return false if candles_15m.nil? || candles_15m.size < 34

    atr = ATR.calculate(candles_15m, 14)
    return false if atr.nil?

    historical = candles_15m.each_cons(20).map { |c| ATR.calculate(c, 14) }.compact
    return false if historical.size < 2

    median = historical.sort[historical.size / 2]
    atr > median
  end
end
