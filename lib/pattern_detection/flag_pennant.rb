# frozen_string_literal: true

require_relative '../technical_indicators'
require_relative 'candle_series'
require_relative 'volume_metrics'

# Flags & Pennants: impulse REL_VOL_15M >= 1.8; flag volume <= 0.6*impulse volume; entry REL_VOL_1M >= 2.0.
module PatternDetection
  class FlagPennant
    IMPULSE_ATR_MULT = 2.0
    REL_VOL_IMPULSE_MIN = 1.8
    FLAG_VOL_MAX_RATIO = 0.6
    REL_VOL_ENTRY_1M_MIN = 2.0
    MAX_FLAG_CANDLES = 10

    def initialize(candles_15m:, candles_5m:, candles_1m: nil, trend_60m:)
      @candles_15m = candles_15m || []
      @candles_5m = candles_5m || []
      @candles_1m = candles_1m || []
      @trend_60m = trend_60m
    end

    def detect_bullish_flag
      ohlcv_15 = PatternDetection::CandleSeries.ohlcv(@candles_15m)
      ohlcv_5 = PatternDetection::CandleSeries.ohlcv(@candles_5m)
      highs_15 = ohlcv_15[:highs]
      lows_15 = ohlcv_15[:lows]
      closes_15 = ohlcv_15[:closes]
      volumes_15 = ohlcv_15[:volumes]

      return invalid('Need 15m bars') if highs_15.size < 10

      atr_15 = TechnicalIndicators.atr(highs_15, lows_15, closes_15, 14)
      return invalid('ATR required') if atr_15.nil?

      impulse_start = closes_15[-15]
      impulse_end = closes_15[-1]
      price_move = (impulse_end - impulse_start).abs
      return invalid("Impulse < #{IMPULSE_ATR_MULT}*ATR") if price_move < IMPULSE_ATR_MULT * atr_15

      vol_15 = PatternDetection::VolumeMetrics.compute(PatternDetection::CandleSeries.ohlcv(@candles_15m))
      return invalid("Impulse: REL_VOL_15M >= #{REL_VOL_IMPULSE_MIN} required") if vol_15[:rel_vol] && vol_15[:rel_vol] < REL_VOL_IMPULSE_MIN

      impulse_vol = volumes_15.last(15).sum
      flag_volumes = ohlcv_5[:volumes]&.last(MAX_FLAG_CANDLES) || []
      flag_vol = flag_volumes.sum
      return invalid("Flag volume must be <= #{FLAG_VOL_MAX_RATIO}*impulse volume") if impulse_vol.positive? && flag_vol > FLAG_VOL_MAX_RATIO * impulse_vol

      closes_5 = ohlcv_5[:closes]
      return invalid('Need 5m bars') if closes_5.size < 3

      flag_high = ohlcv_5[:highs].last(MAX_FLAG_CANDLES).max
      flag_low = ohlcv_5[:lows].last(MAX_FLAG_CANDLES).min
      last_close_5 = closes_5.last
      breakout = last_close_5 > flag_high
      direction_bull = impulse_end > impulse_start

      return invalid('Impulse must be bullish for bullish flag') unless direction_bull
      return invalid('60m trend must align (bullish for CE)') if @trend_60m != :bullish

      ohlcv_1 = PatternDetection::CandleSeries.ohlcv(@candles_1m)
      vol_1 = PatternDetection::VolumeMetrics.compute(ohlcv_1)
      return invalid("Entry: REL_VOL_1M >= #{REL_VOL_ENTRY_1M_MIN} required") if vol_1[:rel_vol] && vol_1[:rel_vol] < REL_VOL_ENTRY_1M_MIN && breakout

      {
        valid: breakout,
        reason: breakout ? 'Bullish flag breakout (5m close > flag high)' : 'Await 5m close above flag high',
        pattern: :flag,
        side: :ce,
        sl: flag_low,
        tp: impulse_end + price_move,
        confirm_close: last_close_5,
        impulse_height: price_move
      }
    end

    def detect_bearish_flag
      ohlcv_15 = PatternDetection::CandleSeries.ohlcv(@candles_15m)
      ohlcv_5 = PatternDetection::CandleSeries.ohlcv(@candles_5m)
      highs_15 = ohlcv_15[:highs]
      lows_15 = ohlcv_15[:lows]
      closes_15 = ohlcv_15[:closes]
      volumes_15 = ohlcv_15[:volumes]

      return invalid('Need 15m bars') if highs_15.size < 10

      atr_15 = TechnicalIndicators.atr(highs_15, lows_15, closes_15, 14)
      return invalid('ATR required') if atr_15.nil?

      impulse_start = closes_15[-15]
      impulse_end = closes_15[-1]
      price_move = (impulse_start - impulse_end).abs
      return invalid("Impulse < #{IMPULSE_ATR_MULT}*ATR") if price_move < IMPULSE_ATR_MULT * atr_15

      closes_5 = ohlcv_5[:closes]
      return invalid('Need 5m bars') if closes_5.size < 3

      flag_high = ohlcv_5[:highs].last(MAX_FLAG_CANDLES).max
      flag_low = ohlcv_5[:lows].last(MAX_FLAG_CANDLES).min
      last_close_5 = closes_5.last
      breakout = last_close_5 < flag_low
      direction_bear = impulse_end < impulse_start

      return invalid('Impulse must be bearish for bearish flag') unless direction_bear
      return invalid('60m trend must align (bearish for PE)') if @trend_60m != :bearish

      ohlcv_1 = PatternDetection::CandleSeries.ohlcv(@candles_1m)
      vol_1 = PatternDetection::VolumeMetrics.compute(ohlcv_1)
      return invalid("Entry: REL_VOL_1M >= #{REL_VOL_ENTRY_1M_MIN} required") if vol_1[:rel_vol] && vol_1[:rel_vol] < REL_VOL_ENTRY_1M_MIN && breakout

      {
        valid: breakout,
        reason: breakout ? 'Bearish flag breakout (5m close < flag low)' : 'Await 5m close below flag low',
        pattern: :flag,
        side: :pe,
        sl: flag_high,
        tp: impulse_end - price_move,
        confirm_close: last_close_5,
        impulse_height: price_move
      }
    end

    def invalid(reason)
      { valid: false, reason: reason, pattern: nil, side: nil, sl: nil, tp: nil, confirm_close: nil }
    end
  end
end
