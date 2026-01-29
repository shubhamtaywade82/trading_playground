# frozen_string_literal: true

class VolumeMetrics
  AVG_PERIOD = 20

  def self.avg_volume(candles, period = AVG_PERIOD)
    return nil if candles.nil? || candles.size < period

    candles.last(period).map(&:volume).sum / period.to_f
  end

  def self.rel_vol(candles, period = AVG_PERIOD)
    return nil if candles.nil? || candles.empty?

    vol = candles.last.volume.to_f
    avg = avg_volume(candles, period)
    return nil if avg.nil? || avg.zero?

    (vol / avg).round(4)
  end
end
