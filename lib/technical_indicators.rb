# frozen_string_literal: true

module TechnicalIndicators
  module_function

  def sma(closes, period)
    return nil if closes.nil? || closes.size < period

    closes.last(period).sum / period.to_f
  end

  def rsi(closes, period = 14)
    return nil if closes.nil? || closes.size < period + 1

    gains = []
    losses = []
    (1...closes.size).each do |i|
      change = closes[i] - closes[i - 1]
      gains << (change.positive? ? change : 0)
      losses << (change.negative? ? change.abs : 0)
    end
    avg_gain = gains.last(period).sum / period.to_f
    avg_loss = losses.last(period).sum / period.to_f
    rs = if avg_loss.zero?
           avg_gain.zero? ? 0 : 100
         else
           (avg_gain / avg_loss)
         end
    100 - (100 / (1 + rs))
  end
end
