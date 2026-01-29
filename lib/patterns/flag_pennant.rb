# frozen_string_literal: true

require_relative 'base_pattern'
require_relative '../indicators/atr'
require_relative '../indicators/volume_metrics'

class FlagPennant < BasePattern
  IMPULSE_ATR_MULT = 2.0
  MAX_FLAG_CANDLES = 10

  def initialize(candles_15m, candles_5m)
    super()
    @candles_15m = candles_15m
    @candles_5m  = candles_5m
  end

  def valid?
    return false if @candles_15m.nil? || @candles_15m.size < 15
    return false if @candles_5m.nil? || @candles_5m.size < MAX_FLAG_CANDLES

    atr = ATR.calculate(@candles_15m, 14)
    return false if atr.nil?

    impulse_start = @candles_15m[-15].close
    impulse_end   = @candles_15m.last.close
    price_move = (impulse_end - impulse_start).abs
    return false if price_move < IMPULSE_ATR_MULT * atr

    impulse_vol = @candles_15m.last(15).map(&:volume).sum
    flag_vol = @candles_5m.last(MAX_FLAG_CANDLES).map(&:volume).sum
    return false if impulse_vol.positive? && flag_vol > 0.6 * impulse_vol

    flag_high = @candles_5m.last(MAX_FLAG_CANDLES).map(&:high).max
    flag_low  = @candles_5m.last(MAX_FLAG_CANDLES).map(&:low).min
    last_close = @candles_5m.last.close
    breakout = last_close > flag_high || last_close < flag_low
    direction_bull = impulse_end > impulse_start

    @signal = {
      sl: last_close > flag_high ? flag_low : flag_high,
      tp: impulse_end + (direction_bull ? price_move : -price_move)
    } if breakout

    breakout
  end

  def direction
    return :neutral if @candles_15m.size < 2

    @candles_15m.last.close > @candles_15m[-2].close ? :bullish : :bearish
  end
end
