# frozen_string_literal: true

require_relative '../technical_indicators'

# Index volume metrics (spot index, not option volume). Precompute for 1m/5m/15m.
# REL_VOL = current volume / SMA(volume, 20). Master filter: REL_VOL_15M >= 1.1.
module PatternDetection
  module VolumeMetrics
    AVG_PERIOD = 20

    module_function

    # Returns { index_vol:, avg_vol:, rel_vol: } for the given OHLCV (last bar = current).
    def compute(ohlcv)
      volumes = ohlcv[:volumes] || []
      return { index_vol: nil, avg_vol: nil, rel_vol: nil } if volumes.empty?

      index_vol = volumes.last.to_f
      avg_vol = TechnicalIndicators.avg_volume(volumes, AVG_PERIOD) if volumes.size >= AVG_PERIOD
      return { index_vol: index_vol, avg_vol: avg_vol, rel_vol: nil } if avg_vol.nil? || avg_vol.zero?

      rel_vol = (index_vol / avg_vol).round(4)
      { index_vol: index_vol, avg_vol: avg_vol, rel_vol: rel_vol }
    end

    # VWAP over the series: sum(typical_price * volume) / sum(volume). typical_price = (high+low+close)/3.
    def vwap(ohlcv)
      highs = ohlcv[:highs] || []
      lows = ohlcv[:lows] || []
      closes = ohlcv[:closes] || []
      volumes = ohlcv[:volumes] || []
      return nil if highs.size != volumes.size || volumes.empty?

      sum_tpv = 0.0
      sum_v = 0.0
      volumes.size.times do |i|
        tp = (highs[i].to_f + lows[i].to_f + closes[i].to_f) / 3.0
        v = volumes[i].to_f
        sum_tpv += tp * v
        sum_v += v
      end
      return nil if sum_v.zero?

      (sum_tpv / sum_v).round(4)
    end

    # Relative volume at a specific bar index (for "REL_VOL_15M during HEAD").
    def rel_vol_at(ohlcv, index)
      volumes = ohlcv[:volumes] || []
      return nil if index < 0 || index >= volumes.size || volumes.size < AVG_PERIOD

      vol_at = volumes[index].to_f
      avg = TechnicalIndicators.avg_volume(volumes[0..index], AVG_PERIOD)
      return nil if avg.nil? || avg.zero?

      (vol_at / avg).round(4)
    end

    # Volume at bar index.
    def volume_at(volumes, index)
      return nil if volumes.nil? || index < 0 || index >= volumes.size
      volumes[index].to_f
    end
  end
end
