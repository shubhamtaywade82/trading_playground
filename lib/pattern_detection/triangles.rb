# frozen_string_literal: true

require_relative '../technical_indicators'
require_relative 'candle_series'
require_relative 'volume_metrics'

# Ascending (CE) / Descending (PE). Compression: REL_VOL_15M < 1.0. Breakout: REL_VOL_5M >= 2.0 (expansion).
module PatternDetection
  class Triangles
    RESISTANCE_TOLERANCE = 0.005
    SUPPORT_TOLERANCE = 0.005
    REL_VOL_COMPRESSION_MAX = 1.0
    REL_VOL_BREAKOUT_MIN = 2.0
    AVG_VOLUME_PERIOD = 20

    def initialize(candles_15m:, candles_5m:, trend_60m:)
      @candles_15m = candles_15m || []
      @candles_5m = candles_5m || []
      @trend_60m = trend_60m
    end

    def detect_ascending
      ohlcv_15 = PatternDetection::CandleSeries.ohlcv(@candles_15m)
      ohlcv_5 = PatternDetection::CandleSeries.ohlcv(@candles_5m)
      highs = ohlcv_15[:highs]
      lows = ohlcv_15[:lows]
      closes = ohlcv_15[:closes]
      volumes = ohlcv_15[:volumes]

      return invalid('Need enough bars') if highs.size < 10

      resistance = approx_equal_highs(highs)
      support_slope = higher_lows_slope(lows)
      return invalid('No flat resistance (approx equal highs)') if resistance.nil?
      return invalid('Support slope must be positive') if support_slope.nil? || support_slope <= 0

      vol_15 = PatternDetection::VolumeMetrics.compute(ohlcv_15)
      return invalid('Triangle: REL_VOL_15M < 1.0 required during compression') if vol_15[:rel_vol] && vol_15[:rel_vol] >= REL_VOL_COMPRESSION_MAX

      last_higher_low = last_higher_low_value(lows)
      triangle_height = resistance - last_higher_low
      last_close_5 = ohlcv_5[:closes]&.last
      vol_5_metrics = PatternDetection::VolumeMetrics.compute(ohlcv_5)
      confirmed = last_close_5 && last_close_5 > resistance
      volume_ok = vol_5_metrics[:rel_vol].nil? || vol_5_metrics[:rel_vol] >= REL_VOL_BREAKOUT_MIN
      confirmed = confirmed && volume_ok if confirmed

      {
        valid: confirmed,
        reason: confirmed ? 'Ascending triangle breakout (5m close > resistance, volume)' : 'Await 5m close above resistance with volume',
        pattern: :ascending_triangle,
        side: :ce,
        sl: last_higher_low,
        tp: resistance + triangle_height,
        confirm_close: last_close_5,
        resistance: resistance,
        last_higher_low: last_higher_low
      }
    end

    def detect_descending
      ohlcv_15 = PatternDetection::CandleSeries.ohlcv(@candles_15m)
      ohlcv_5 = PatternDetection::CandleSeries.ohlcv(@candles_5m)
      highs = ohlcv_15[:highs]
      lows = ohlcv_15[:lows]
      closes = ohlcv_15[:closes]
      volumes = ohlcv_15[:volumes]

      return invalid('Need enough bars') if lows.size < 10

      support = approx_equal_lows(lows)
      resistance_slope = lower_highs_slope(highs)
      return invalid('No flat support (approx equal lows)') if support.nil?
      return invalid('Resistance slope must be negative') if resistance_slope.nil? || resistance_slope >= 0

      vol_15 = PatternDetection::VolumeMetrics.compute(ohlcv_15)
      return invalid('Triangle: REL_VOL_15M < 1.0 required during compression') if vol_15[:rel_vol] && vol_15[:rel_vol] >= REL_VOL_COMPRESSION_MAX

      last_lower_high = last_lower_high_value(highs)
      triangle_height = last_lower_high - support
      last_close_5 = ohlcv_5[:closes]&.last
      vol_5_metrics = PatternDetection::VolumeMetrics.compute(ohlcv_5)
      confirmed = last_close_5 && last_close_5 < support
      volume_ok = vol_5_metrics[:rel_vol].nil? || vol_5_metrics[:rel_vol] >= REL_VOL_BREAKOUT_MIN
      confirmed = confirmed && volume_ok if confirmed

      {
        valid: confirmed,
        reason: confirmed ? 'Descending triangle breakdown (5m close < support, volume)' : 'Await 5m close below support with volume',
        pattern: :descending_triangle,
        side: :pe,
        sl: last_lower_high,
        tp: support - triangle_height,
        confirm_close: last_close_5,
        support: support,
        last_lower_high: last_lower_high
      }
    end

    private

    def approx_equal_highs(highs)
      return nil if highs.size < 4
      recent = highs.last(15)
      avg = recent.sum / recent.size.to_f
      return nil if recent.any? { |h| (h - avg).abs / avg > RESISTANCE_TOLERANCE }
      avg
    end

    def approx_equal_lows(lows)
      return nil if lows.size < 4
      recent = lows.last(15)
      avg = recent.sum / recent.size.to_f
      return nil if recent.any? { |l| (l - avg).abs / avg > SUPPORT_TOLERANCE }
      avg
    end

    def higher_lows_slope(lows)
      return nil if lows.size < 5
      idx = (0...lows.size).to_a
      recent_lows = lows.last(8).each_with_index.map { |v, i| [i, v] }
      return nil if recent_lows.size < 2
      x_mean = recent_lows.map(&:first).sum / recent_lows.size.to_f
      y_mean = recent_lows.map(&:last).sum / recent_lows.size.to_f
      num = recent_lows.sum { |x, y| (x - x_mean) * (y - y_mean) }
      den = recent_lows.sum { |x, _| (x - x_mean)**2 }
      return nil if den.zero?
      num / den
    end

    def lower_highs_slope(highs)
      return nil if highs.size < 5
      recent_highs = highs.last(8).each_with_index.map { |v, i| [i, v] }
      return nil if recent_highs.size < 2
      x_mean = recent_highs.map(&:first).sum / recent_highs.size.to_f
      y_mean = recent_highs.map(&:last).sum / recent_highs.size.to_f
      num = recent_highs.sum { |x, y| (x - x_mean) * (y - y_mean) }
      den = recent_highs.sum { |x, _| (x - x_mean)**2 }
      return nil if den.zero?
      num / den
    end

    def last_higher_low_value(lows)
      return nil if lows.size < 3
      lows.last(5).min
    end

    def last_lower_high_value(highs)
      return nil if highs.size < 3
      highs.last(5).max
    end

    def invalid(reason)
      { valid: false, reason: reason, pattern: nil, side: nil, sl: nil, tp: nil, confirm_close: nil }
    end
  end
end
