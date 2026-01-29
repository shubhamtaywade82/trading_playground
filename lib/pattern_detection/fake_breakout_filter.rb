# frozen_string_literal: true

require_relative 'volume_metrics'

# Fake breakout: price breaks level but REL_VOL_5M < 1.0 → do NOT buy option.
# Saves capital; 90% retail losses happen here.
module PatternDetection
  class FakeBreakoutFilter
    REL_VOL_MIN = 1.0

    def initialize(ohlcv_5m:)
      @ohlcv_5m = ohlcv_5m || {}
    end

    # Returns { fake: true/false, reason: string }. fake=true means do NOT trade.
    def check(price_breaks_level:)
      return { fake: false, reason: 'No level break' } unless price_breaks_level

      vol = PatternDetection::VolumeMetrics.compute(@ohlcv_5m)
      fake = vol[:rel_vol] && vol[:rel_vol] < REL_VOL_MIN
      reason = fake ? "Fake breakout: REL_VOL_5M #{vol[:rel_vol]} < #{REL_VOL_MIN} — do NOT buy option" : 'Breakout with volume'
      { fake: fake, reason: reason }
    end
  end
end
