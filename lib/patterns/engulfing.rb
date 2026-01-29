# frozen_string_literal: true

require_relative 'base_pattern'
require_relative '../indicators/rsi'

class Engulfing < BasePattern
  RSI_OVERSOLD = 35

  def initialize(candles_5m, support_level: nil, resistance_level: nil)
    super()
    @candles_5m = candles_5m
    @support_level = support_level
    @resistance_level = resistance_level
  end

  def valid?
    return false if @candles_5m.nil? || @candles_5m.size < 2

    c1 = @candles_5m[-2]
    c2 = @candles_5m[-1]
    bearish1 = c1.close < c1.open
    bullish2 = c2.close > c2.open
    return false unless bearish1 && bullish2
    return false unless c2.open < c1.close && c2.close > c1.open

    return false unless at_level?(c2)
    rsi = RSI.calculate(@candles_5m, 14)
    return false if rsi && rsi >= RSI_OVERSOLD

    @signal = { sl: c2.low, tp: @resistance_level }
    true
  end

  def direction
    :bullish
  end

  private

  def at_level?(candle)
    return true if @support_level.nil? && @resistance_level.nil?

    mid = (candle.close + candle.open) / 2.0
    level = @support_level || @resistance_level
    return false if level.nil?

    (mid - level).abs / level < 0.01
  end
end
