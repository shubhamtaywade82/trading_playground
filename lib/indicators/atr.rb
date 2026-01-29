# frozen_string_literal: true

class ATR
  def self.calculate(candles, period)
    return nil if candles.nil? || candles.size < period + 1

    trs = candles.each_cons(2).map do |prev, curr|
      [
        curr.high - curr.low,
        (curr.high - prev.close).abs,
        (curr.low - prev.close).abs
      ].max
    end
    trs.last(period).sum / period.to_f
  end
end
