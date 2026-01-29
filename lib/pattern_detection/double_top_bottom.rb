# frozen_string_literal: true

require_relative '../smc'
require_relative '../technical_indicators'
require_relative 'candle_series'
require_relative 'volume_metrics'

# Double Top (bearish) / Double Bottom (bullish). Structure 15m, trigger 5m. Institutional: volume(top2)<volume(top1); trigger volume >= 1.5*AVG_VOL_5M.
module PatternDetection
  class DoubleTopBottom
    TOP_TOLERANCE = 0.02
    BOTTOM_TOLERANCE = 0.02
    TRIGGER_VOL_MULT = 1.5

    def initialize(candles_15m:, candles_5m:, trend_60m:)
      @candles_15m = candles_15m || []
      @candles_5m = candles_5m || []
      @trend_60m = trend_60m
    end

    def detect_double_top
      ohlcv_15 = PatternDetection::CandleSeries.ohlcv(@candles_15m)
      ohlcv_5 = PatternDetection::CandleSeries.ohlcv(@candles_5m)
      highs = ohlcv_15[:highs]
      lows = ohlcv_15[:lows]
      closes = ohlcv_15[:closes]

      sh = SMC.swing_highs_with_index(highs, window: 2)
      sl = SMC.swing_lows_with_index(lows, window: 2)
      return invalid('Need at least 2 swing highs') if sh.size < 2

      top1 = sh[-2]
      top2 = sh[-1]
      return invalid('Tops too far apart') if (top1[:value] - top2[:value]).abs / top1[:value] > TOP_TOLERANCE

      between_lows = lows[top1[:index]...top2[:index]]
      swing_low_between = between_lows.min
      return invalid('No swing low between tops') if swing_low_between.nil?

      rsi1 = TechnicalIndicators.rsi_at(closes, 14, top1[:index])
      rsi2 = TechnicalIndicators.rsi_at(closes, 14, top2[:index])
      return invalid('RSI at TOP2 should be < RSI at TOP1 (bearish divergence)') if rsi1 && rsi2 && rsi2 >= rsi1

      volumes_15 = ohlcv_15[:volumes]
      vol_top1 = PatternDetection::VolumeMetrics.volume_at(volumes_15, top1[:index])
      vol_top2 = PatternDetection::VolumeMetrics.volume_at(volumes_15, top2[:index])
      return invalid('Volume(top2) < volume(top1) required (institutional confirmation)') if vol_top1 && vol_top2 && vol_top2 >= vol_top1

      last_close_5 = ohlcv_5[:closes]&.last
      vol_5 = ohlcv_5[:volumes]&.last
      avg_vol_5 = TechnicalIndicators.avg_volume(ohlcv_5[:volumes], 20) if ohlcv_5[:volumes]&.size >= 20
      trigger_vol_ok = avg_vol_5.nil? || (vol_5 && vol_5 >= TRIGGER_VOL_MULT * avg_vol_5)
      return invalid('5m breakdown candle volume >= 1.5*AVG_VOL_5M required') unless trigger_vol_ok

      confirmed = last_close_5 && last_close_5 < swing_low_between
      height = top1[:value] - swing_low_between
      tp = swing_low_between - height

      {
        valid: confirmed,
        reason: confirmed ? 'Double top confirmed (5m close < neckline)' : 'Await 5m close below swing low between tops',
        pattern: :double_top,
        side: :pe,
        sl: top2[:value],
        tp: tp,
        confirm_close: last_close_5,
        top1: top1[:value],
        top2: top2[:value],
        neckline: swing_low_between
      }
    end

    def detect_double_bottom
      ohlcv_15 = PatternDetection::CandleSeries.ohlcv(@candles_15m)
      ohlcv_5 = PatternDetection::CandleSeries.ohlcv(@candles_5m)
      highs = ohlcv_15[:highs]
      lows = ohlcv_15[:lows]
      closes = ohlcv_15[:closes]

      sl = SMC.swing_lows_with_index(lows, window: 2)
      sh = SMC.swing_highs_with_index(highs, window: 2)
      return invalid('Need at least 2 swing lows') if sl.size < 2

      bot1 = sl[-2]
      bot2 = sl[-1]
      return invalid('Bottoms too far apart') if (bot1[:value] - bot2[:value]).abs / bot1[:value] > BOTTOM_TOLERANCE

      between_highs = highs[bot1[:index]...bot2[:index]]
      swing_high_between = between_highs.max
      return invalid('No swing high between bottoms') if swing_high_between.nil?

      rsi1 = TechnicalIndicators.rsi_at(closes, 14, bot1[:index])
      rsi2 = TechnicalIndicators.rsi_at(closes, 14, bot2[:index])
      return invalid('RSI at BOT2 should be > RSI at BOT1 (bullish divergence)') if rsi1 && rsi2 && rsi2 <= rsi1

      volumes_15 = ohlcv_15[:volumes]
      vol_bot1 = PatternDetection::VolumeMetrics.volume_at(volumes_15, bot1[:index])
      vol_bot2 = PatternDetection::VolumeMetrics.volume_at(volumes_15, bot2[:index])
      return invalid('Volume(bot2) < volume(bot1) required (institutional confirmation)') if vol_bot1 && vol_bot2 && vol_bot2 >= vol_bot1

      vol_5 = ohlcv_5[:volumes]&.last
      avg_vol_5 = TechnicalIndicators.avg_volume(ohlcv_5[:volumes], 20) if ohlcv_5[:volumes]&.size >= 20
      trigger_vol_ok = avg_vol_5.nil? || (vol_5 && vol_5 >= TRIGGER_VOL_MULT * avg_vol_5)
      return invalid('5m breakout candle volume >= 1.5*AVG_VOL_5M required') unless trigger_vol_ok

      last_close_5 = ohlcv_5[:closes]&.last
      confirmed = last_close_5 && last_close_5 > swing_high_between
      height = swing_high_between - bot1[:value]
      tp = swing_high_between + height

      {
        valid: confirmed,
        reason: confirmed ? 'Double bottom confirmed (5m close > neckline)' : 'Await 5m close above swing high between bottoms',
        pattern: :double_bottom,
        side: :ce,
        sl: bot2[:value],
        tp: tp,
        confirm_close: last_close_5,
        bottom1: bot1[:value],
        bottom2: bot2[:value],
        neckline: swing_high_between
      }
    end

    def invalid(reason)
      { valid: false, reason: reason, pattern: nil, side: nil, sl: nil, tp: nil, confirm_close: nil }
    end
  end
end
