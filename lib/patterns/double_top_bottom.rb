# frozen_string_literal: true

require_relative 'base_pattern'
require_relative 'swing_detector'
require_relative '../indicators/rsi'

class DoubleTopBottom < BasePattern
  TOP_TOLERANCE = 0.02

  def initialize(candles_15m, candles_5m)
    super()
    @candles_15m = candles_15m
    @candles_5m  = candles_5m
  end

  def valid?
    highs = SwingDetector.highs(@candles_15m)
    return false unless highs.size >= 2

    top1 = highs[-2]
    top2 = highs[-1]
    return false unless (top1.high - top2.high).abs / top1.high < TOP_TOLERANCE

    idx1 = @candles_15m.index(top1)
    idx2 = @candles_15m.index(top2)
    return false if idx1.nil? || idx2.nil?

    rsi1 = RSI.calculate(@candles_15m[0..idx1], 14)
    rsi2 = RSI.calculate(@candles_15m[0..idx2], 14)
    return false if rsi1 && rsi2 && rsi2 >= rsi1

    between = @candles_15m[idx1...idx2]
    swing_low_between = between.map(&:low).min
    return false if swing_low_between.nil? || @candles_5m.empty?

    confirmed = @candles_5m.last.close < swing_low_between
    @signal = { neckline: swing_low_between, sl: top2.high, tp: swing_low_between - (top1.high - swing_low_between) } if confirmed
    confirmed
  end

  def direction
    :bearish
  end
end
