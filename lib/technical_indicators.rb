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

  # Average True Range (period default 14). Inputs: highs, lows, closes (oldest first).
  def atr(highs, lows, closes, period = 14)
    return nil if highs.nil? || lows.nil? || closes.nil?
    return nil if highs.size < 2 || highs.size != lows.size || highs.size != closes.size
    return nil if highs.size < period + 1

    trs = []
    (1...highs.size).each do |i|
      hl = highs[i] - lows[i]
      hc = (highs[i] - closes[i - 1]).abs
      lc = (lows[i] - closes[i - 1]).abs
      trs << [hl, hc, lc].max
    end
    trs.last(period).sum / period.to_f
  end
end
