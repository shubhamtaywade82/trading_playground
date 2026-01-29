# frozen_string_literal: true

require_relative '../smc'
require_relative '../technical_indicators'
require_relative 'candle_series'
require_relative 'volume_metrics'

# Bearish H&S: structure on 15m, confirmation on 5m. Volume-strict: volume(LS)>volume(RS), volume(HEAD)>=volume(LS), REL_VOL_15M at HEAD>=1.3; confirm REL_VOL_5M>=1.5.
module PatternDetection
  class HeadAndShoulders
    SYMMETRY_TOLERANCE = 0.03
    REL_VOL_HEAD_MIN = 1.3
    REL_VOL_CONFIRM_5M = 1.5

    def initialize(candles_15m:, candles_5m:, trend_60m:)
      @candles_15m = candles_15m || []
      @candles_5m = candles_5m || []
      @trend_60m = trend_60m
    end

    def detect_bearish
      ohlcv_15 = PatternDetection::CandleSeries.ohlcv(@candles_15m)
      highs = ohlcv_15[:highs]
      lows = ohlcv_15[:lows]
      volumes = ohlcv_15[:volumes]

      sh = SMC.swing_highs_with_index(highs, window: 2)
      sl = SMC.swing_lows_with_index(lows, window: 2)
      return invalid('Need at least 3 swing highs and 2 swing lows') if sh.size < 3 || sl.size < 2

      ls = sh[-3]
      head = sh[-2]
      rs = sh[-1]
      return invalid('Head must be higher than left shoulder') unless head[:value] > ls[:value]
      return invalid('Right shoulder must be lower than head') unless rs[:value] < head[:value]

      low_ls_head = sl.select { |x| x[:index] > ls[:index] && x[:index] < head[:index] }.max_by { |x| x[:value] }
      low_head_rs = sl.select { |x| x[:index] > head[:index] && x[:index] < rs[:index] }.max_by { |x| x[:value] }
      return invalid('Neckline: need swing low between LS–Head and Head–RS') if low_ls_head.nil? || low_head_rs.nil?

      neckline_at_rs = neckline_value(low_ls_head[:value], low_head_rs[:value], rs[:index], ls[:index], head[:index], low_ls_head[:index], low_head_rs[:index])
      symmetry = (ls[:value] - rs[:value]).abs / head[:value]
      return invalid("Symmetry tolerance exceeded: #{symmetry.round(4)}") if symmetry > SYMMETRY_TOLERANCE

      vol_ls = volume_at(volumes, ls[:index])
      vol_head = volume_at(volumes, head[:index])
      vol_rs = volume_at(volumes, rs[:index])
      return invalid('Volume(LS) > volume(RS) required') if vol_ls && vol_rs && vol_ls <= vol_rs
      return invalid('Volume(HEAD) >= volume(LS) required') if vol_head && vol_ls && vol_head < vol_ls

      rel_vol_head = PatternDetection::VolumeMetrics.rel_vol_at(ohlcv_15, head[:index])
      return invalid("REL_VOL_15M during HEAD >= #{REL_VOL_HEAD_MIN} required") if rel_vol_head && rel_vol_head < REL_VOL_HEAD_MIN

      return invalid('Prior trend must be bullish for bearish H&S') if @trend_60m != :bullish

      ohlcv_5 = PatternDetection::CandleSeries.ohlcv(@candles_5m)
      confirm = confirmation_bearish(neckline_at_rs, ohlcv_15, ohlcv_5)
      sl_price = rs[:value]
      target_points = head[:value] - neckline_at_rs
      tp_price = neckline_at_rs - target_points

      {
        valid: confirm[:confirmed],
        reason: confirm[:confirmed] ? 'Bearish H&S confirmed' : confirm[:reason],
        pattern: :head_and_shoulders,
        side: :pe,
        neckline: neckline_at_rs,
        sl: sl_price,
        tp: tp_price,
        confirm_candle_close: confirm[:close],
        head: head[:value],
        left_shoulder: ls[:value],
        right_shoulder: rs[:value]
      }
    end

    def detect_inverse_bullish
      ohlcv_15 = PatternDetection::CandleSeries.ohlcv(@candles_15m)
      highs = ohlcv_15[:highs]
      lows = ohlcv_15[:lows]
      volumes = ohlcv_15[:volumes]

      sh = SMC.swing_highs_with_index(highs, window: 2)
      sl = SMC.swing_lows_with_index(lows, window: 2)
      return invalid('Need at least 2 swing highs and 3 swing lows') if sh.size < 2 || sl.size < 3

      ls = sl[-3]
      head = sl[-2]
      rs = sl[-1]
      return invalid('Head must be lower than left shoulder') unless head[:value] < ls[:value]
      return invalid('Right shoulder must be higher than head') unless rs[:value] > head[:value]

      high_ls_head = sh.select { |x| x[:index] > ls[:index] && x[:index] < head[:index] }.min_by { |x| x[:value] }
      high_head_rs = sh.select { |x| x[:index] > head[:index] && x[:index] < rs[:index] }.min_by { |x| x[:value] }
      return invalid('Neckline: need swing high between LS–Head and Head–RS') if high_ls_head.nil? || high_head_rs.nil?

      neckline_at_rs = neckline_value_high(high_ls_head[:value], high_head_rs[:value], rs[:index], ls[:index], head[:index], high_ls_head[:index], high_head_rs[:index])
      symmetry = (ls[:value] - rs[:value]).abs / head[:value].abs
      return invalid("Symmetry tolerance exceeded: #{symmetry.round(4)}") if symmetry > SYMMETRY_TOLERANCE

      return invalid('Prior trend must be bearish for inverse H&S') if @trend_60m != :bearish

      ohlcv_5 = PatternDetection::CandleSeries.ohlcv(@candles_5m)
      confirm = confirmation_bullish(neckline_at_rs, ohlcv_15, ohlcv_5)
      sl_price = rs[:value]
      target_points = neckline_at_rs - head[:value]
      tp_price = neckline_at_rs + target_points

      {
        valid: confirm[:confirmed],
        reason: confirm[:confirmed] ? 'Inverse H&S confirmed' : confirm[:reason],
        pattern: :inverse_head_and_shoulders,
        side: :ce,
        neckline: neckline_at_rs,
        sl: sl_price,
        tp: tp_price,
        confirm_candle_close: confirm[:close],
        head: head[:value],
        left_shoulder: ls[:value],
        right_shoulder: rs[:value]
      }
    end

    private

    def neckline_value(low1, low2, i_rs, i_ls, i_head, i_low1, i_low2)
      return low2 if low1 == low2
      slope = (low2 - low1).to_f / (i_low2 - i_low1)
      low1 + slope * (i_rs - i_low1)
    end

    def neckline_value_high(high1, high2, i_rs, i_ls, i_head, i_high1, i_high2)
      return high2 if high1 == high2
      slope = (high2 - high1).to_f / (i_high2 - i_high1)
      high1 + slope * (i_rs - i_high1)
    end

    def volume_at(volumes, index)
      return nil if volumes.nil? || index >= volumes.size
      volumes[index]
    end

    def confirmation_bearish(neckline, ohlcv_15, ohlcv_5)
      closes_5 = ohlcv_5[:closes]
      last_close = closes_5&.last
      return { confirmed: false, reason: 'No 5m close', close: nil } if last_close.nil?

      vol_5 = PatternDetection::VolumeMetrics.compute(ohlcv_5)
      return { confirmed: false, reason: 'Neckline break without volume: REL_VOL_5M >= 1.5 required', close: last_close } if vol_5[:rel_vol] && vol_5[:rel_vol] < REL_VOL_CONFIRM_5M

      confirmed = last_close < neckline
      { confirmed: confirmed, reason: confirmed ? '5m close below neckline, REL_VOL_5M>=1.5' : 'Await 5m close below neckline', close: last_close }
    end

    def confirmation_bullish(neckline, ohlcv_15, ohlcv_5)
      closes_5 = ohlcv_5[:closes]
      last_close = closes_5&.last
      return { confirmed: false, reason: 'No 5m close', close: nil } if last_close.nil?

      vol_5 = PatternDetection::VolumeMetrics.compute(ohlcv_5)
      return { confirmed: false, reason: 'Neckline break without volume: REL_VOL_5M >= 1.5 required', close: last_close } if vol_5[:rel_vol] && vol_5[:rel_vol] < REL_VOL_CONFIRM_5M

      confirmed = last_close > neckline
      { confirmed: confirmed, reason: confirmed ? '5m close above neckline, REL_VOL_5M>=1.5' : 'Await 5m close above neckline', close: last_close }
    end

    def invalid(reason)
      { valid: false, reason: reason, pattern: :head_and_shoulders, side: nil, neckline: nil, sl: nil, tp: nil, confirm_candle_close: nil }
    end
  end
end
