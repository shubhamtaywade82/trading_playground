# frozen_string_literal: true

class EMA
  def self.calculate(candles, period)
    return nil if candles.nil? || candles.size < period

    k = 2.0 / (period + 1)
    ema = candles.first(period).map(&:close).sum / period.to_f
    candles.drop(period).each do |c|
      ema = c.close * k + ema * (1 - k)
    end
    ema
  end
end
