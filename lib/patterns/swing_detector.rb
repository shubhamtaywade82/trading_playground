# frozen_string_literal: true

# Returns swing points in chronological order: { type: :high|:low, candle:, price: }.
# Used by H&S, Triangle, etc. Window = 2 each side for local swing.
class SwingDetector
  WINDOW = 2

  def self.detect(candles)
    return [] if candles.nil? || candles.size < (WINDOW * 2) + 1

    highs = candles.map(&:high)
    lows = candles.map(&:low)
    out = []

    (WINDOW...(candles.size - WINDOW)).each do |i|
      if (i - WINDOW..i + WINDOW).all? { |j| j == i || highs[j] <= highs[i] }
        out << { type: :high, candle: candles[i], price: highs[i] }
      end
      if (i - WINDOW..i + WINDOW).all? { |j| j == i || lows[j] >= lows[i] }
        out << { type: :low, candle: candles[i], price: lows[i] }
      end
    end

    out.sort_by { |s| candles.index(s[:candle]) }
  end

  def self.highs(candles)
    detect(candles).select { |s| s[:type] == :high }.map { |s| s[:candle] }
  end

  def self.lows(candles)
    detect(candles).select { |s| s[:type] == :low }.map { |s| s[:candle] }
  end
end
