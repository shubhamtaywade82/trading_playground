# frozen_string_literal: true

# Multi-timeframe filter: CE requires 60m bullish; PE requires 60m bearish.
# If mismatch → skip trade.
module PatternDetection
  class MTFFilter
    def initialize(trend_60m:)
      @trend_60m = trend_60m
    end

    # Returns { passed: true/false, reason: string }
    def allow_ce?
      passed = @trend_60m == :bullish
      { passed: passed, reason: passed ? '60m bullish — CE allowed' : '60m not bullish — skip CE' }
    end

    def allow_pe?
      passed = @trend_60m == :bearish
      { passed: passed, reason: passed ? '60m bearish — PE allowed' : '60m not bearish — skip PE' }
    end

    def allow_side(side)
      case side
      when :ce then allow_ce?
      when :pe then allow_pe?
      else { passed: false, reason: "Unknown side: #{side}" }
      end
    end
  end
end
