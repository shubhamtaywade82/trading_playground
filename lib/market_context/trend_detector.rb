# frozen_string_literal: true

require_relative '../indicators/ema'

class TrendDetector
  def self.call(candles_60m)
    return :neutral if candles_60m.nil? || candles_60m.size < 200

    ema50  = EMA.calculate(candles_60m, 50)
    ema200 = EMA.calculate(candles_60m, 200)

    return :neutral if ema50.nil? || ema200.nil?
    return :bullish if ema50 > ema200
    return :bearish if ema50 < ema200

    :neutral
  end
end
