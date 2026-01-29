# frozen_string_literal: true

require_relative 'base_pattern'
require_relative 'swing_detector'

class Triangle < BasePattern
  def initialize(candles_15m, candles_5m)
    super()
    @candles_15m = candles_15m
    @candles_5m  = candles_5m
  end

  def valid?
    highs = SwingDetector.highs(@candles_15m)
    lows  = SwingDetector.lows(@candles_15m)

    return false unless highs.size >= 2 && lows.size >= 2

    resistance = highs.map(&:high).max
    support    = lows.map(&:low).min
    last_high  = highs.last.high
    last_low   = lows.last.low

    return false if @candles_5m.empty?

    last_close = @candles_5m.last.close
    breakout_up   = last_close > resistance
    breakout_down = last_close < support
    breakout = breakout_up || breakout_down

    @signal = {
      resistance: resistance,
      support: support,
      sl: breakout_up ? last_low : last_high,
      tp: breakout_up ? resistance + (resistance - last_low) : support - (last_high - support)
    } if breakout

    breakout
  end

  def direction
    return :neutral if @candles_5m.nil? || @candles_5m.empty?

    last_close = @candles_5m.last.close
    highs = SwingDetector.highs(@candles_15m)
    max_high = highs.map(&:high).max
    last_close > max_high ? :bullish : :bearish
  end
end
