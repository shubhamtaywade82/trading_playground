# frozen_string_literal: true

require_relative '../technical_indicators'
require_relative 'candle_series'
require_relative 'volume_metrics'

# Engulfing at levels only. REL_VOL_5M >= 1.5 required. Engulfing without volume = noise.
module PatternDetection
  class EngulfingAtLevel
    RSI_OVERSOLD = 35
    RSI_OVERBOUGHT = 65
    REL_VOL_5M_MIN = 1.5

    def initialize(candles_5m:, support_level: nil, resistance_level: nil, vwap: nil, fib_618: nil)
      @candles_5m = candles_5m || []
      @support = support_level
      @resistance = resistance_level
      @vwap = vwap
      @fib_618 = fib_618
    end

    def detect_bullish
      ohlcv = PatternDetection::CandleSeries.ohlcv(@candles_5m)
      opens = ohlcv[:opens]
      highs = ohlcv[:highs]
      lows = ohlcv[:lows]
      closes = ohlcv[:closes]

      return invalid('Need at least 2 candles') if closes.size < 2

      c1_open = opens[-2]
      c1_close = closes[-2]
      c2_open = opens[-1]
      c2_close = closes[-1]
      red1 = c1_close < c1_open
      green2 = c2_close > c2_open
      return invalid('C1 must be red, C2 must be green') unless red1 && green2
      return invalid('C2 open < C1 close required') unless c2_open < c1_close
      return invalid('C2 close > C1 open required') unless c2_close > c1_open

      at_level = at_support?(c2_close, c2_open)
      return invalid('Bullish engulfing only valid at support / VWAP / fib 61.8') unless at_level

      vol_5 = PatternDetection::VolumeMetrics.compute(ohlcv)
      return invalid("REL_VOL_5M >= #{REL_VOL_5M_MIN} required (engulfing without volume = noise)") if vol_5[:rel_vol] && vol_5[:rel_vol] < REL_VOL_5M_MIN

      rsi = TechnicalIndicators.rsi(closes, 14)
      return invalid("RSI(5m) should be < #{RSI_OVERSOLD} at support") if rsi && rsi >= RSI_OVERSOLD

      {
        valid: true,
        reason: 'Bullish engulfing at level',
        pattern: :bullish_engulfing,
        side: :ce,
        sl: lows[-1],
        tp: @resistance,
        confirm_close: c2_close
      }
    end

    def detect_bearish
      ohlcv = PatternDetection::CandleSeries.ohlcv(@candles_5m)
      opens = ohlcv[:opens]
      highs = ohlcv[:highs]
      lows = ohlcv[:lows]
      closes = ohlcv[:closes]

      return invalid('Need at least 2 candles') if closes.size < 2

      c1_open = opens[-2]
      c1_close = closes[-2]
      c2_open = opens[-1]
      c2_close = closes[-1]
      green1 = c1_close > c1_open
      red2 = c2_close < c2_open
      return invalid('C1 must be green, C2 must be red') unless green1 && red2
      return invalid('C2 open > C1 close required') unless c2_open > c1_close
      return invalid('C2 close < C1 open required') unless c2_close < c1_open

      at_level = at_resistance?(c2_close, c2_open)
      return invalid('Bearish engulfing only valid at resistance') unless at_level

      vol_5 = PatternDetection::VolumeMetrics.compute(ohlcv)
      return invalid("REL_VOL_5M >= #{REL_VOL_5M_MIN} required (engulfing without volume = noise)") if vol_5[:rel_vol] && vol_5[:rel_vol] < REL_VOL_5M_MIN

      rsi = TechnicalIndicators.rsi(closes, 14)
      return invalid("RSI(5m) should be > #{RSI_OVERBOUGHT} at resistance") if rsi && rsi <= RSI_OVERBOUGHT

      {
        valid: true,
        reason: 'Bearish engulfing at level',
        pattern: :bearish_engulfing,
        side: :pe,
        sl: highs[-1],
        tp: @support,
        confirm_close: c2_close
      }
    end

    def at_support?(close, open)
      level = @support || @fib_618 || @vwap
      return false if level.nil?
      mid = (close + open) / 2.0
      (mid - level).abs / level < 0.01
    end

    def at_resistance?(close, open)
      level = @resistance
      return false if level.nil?
      mid = (close + open) / 2.0
      (mid - level).abs / level < 0.01
    end

    def invalid(reason)
      { valid: false, reason: reason, pattern: nil, side: nil, sl: nil, tp: nil, confirm_close: nil }
    end
  end
end
