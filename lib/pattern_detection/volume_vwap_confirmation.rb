# frozen_string_literal: true

require_relative 'volume_metrics'

# Volume + VWAP: bullish if price > VWAP and REL_VOL_5M >= 1.2; bearish if price < VWAP and REL_VOL_5M >= 1.2.
# VWAP without volume = irrelevant.
module PatternDetection
  class VolumeVwapConfirmation
    REL_VOL_MIN = 1.2

    def initialize(ohlcv_5m:, vwap:)
      @ohlcv_5m = ohlcv_5m || {}
      @vwap = vwap
    end

    # Returns { confirmed: true/false, bias: :bullish|:bearish|nil, reason: string }
    def run
      return { confirmed: false, bias: nil, reason: 'No VWAP' } if @vwap.nil?

      vol = PatternDetection::VolumeMetrics.compute(@ohlcv_5m)
      return { confirmed: false, bias: nil, reason: "REL_VOL_5M < #{REL_VOL_MIN} (VWAP without volume = irrelevant)" } if vol[:rel_vol].nil? || vol[:rel_vol] < REL_VOL_MIN

      last_close = @ohlcv_5m[:closes]&.last
      return { confirmed: false, bias: nil, reason: 'No close' } if last_close.nil?

      if last_close > @vwap
        { confirmed: true, bias: :bullish, reason: "Price > VWAP, REL_VOL_5M=#{vol[:rel_vol]}" }
      elsif last_close < @vwap
        { confirmed: true, bias: :bearish, reason: "Price < VWAP, REL_VOL_5M=#{vol[:rel_vol]}" }
      else
        { confirmed: false, bias: nil, reason: 'Price at VWAP' }
      end
    end
  end
end
