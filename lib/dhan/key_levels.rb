# frozen_string_literal: true

# Derives resistance/support from swing highs/lows (SMC).
require_relative '../smc'

module Dhan
  class KeyLevels
    class << self
      def from_ohlc(highs, lows)
        return { resistance: [], support: [] } if highs.nil? || lows.nil? || highs.size < 5 || lows.size < 5

        sh = SMC.swing_highs(highs)
        sl = SMC.swing_lows(lows)
        { resistance: sh.last(3).reverse, support: sl.last(3).reverse }
      end
    end
  end
end
