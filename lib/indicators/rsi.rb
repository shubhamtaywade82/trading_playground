# frozen_string_literal: true

class RSI
  def self.calculate(candles, period = 14)
    return nil if candles.nil? || candles.size < period + 1

    gains = []
    losses = []

    candles.each_cons(2) do |a, b|
      change = b.close - a.close
      gains << [change, 0].max
      losses << [-change, 0].max
    end

    avg_gain = gains.last(period).sum / period.to_f
    avg_loss = losses.last(period).sum / period.to_f

    return 100.0 if avg_loss.zero?
    100 - (100 / (1 + avg_gain / avg_loss))
  end
end
