# frozen_string_literal: true

require 'date'

# Builds suggested option strike symbols from option chain for display (e.g. strike to trade).
# Single responsibility: derive ATM ± offset strikes from chain and format as NSE-style symbols.
module Dhan
  class StrikeSuggestions
    ATM_OFFSETS = [-1, 0, 1].freeze # strikes around ATM

    class << self
      def suggest(oc, spot_price, expiry_yyyymmdd, underlying_symbol)
        return empty_suggestions unless oc.is_a?(Hash) && spot_price.is_a?(Numeric)
        return empty_suggestions if expiry_yyyymmdd.to_s.strip.empty? || underlying_symbol.to_s.strip.empty?

        strikes = numeric_strikes_sorted(oc)
        return empty_suggestions if strikes.empty?

        atm_index = strikes.index(strikes.min_by { |s| (s - spot_price).abs }) || 0
        selected = ATM_OFFSETS.filter_map { |off| strikes[atm_index + off] }.uniq

        {
          ce: selected.map { |s| index_option_symbol(underlying_symbol, expiry_yyyymmdd, s, :ce) },
          pe: selected.map { |s| index_option_symbol(underlying_symbol, expiry_yyyymmdd, s, :pe) }
        }
      end

      private

      def empty_suggestions
        { ce: [], pe: [] }
      end

      def numeric_strikes_sorted(oc)
        oc.keys.filter_map { |k| Float(k.to_s) rescue nil }.sort
      end

      def index_option_symbol(underlying, expiry_yyyymmdd, strike, ce_or_pe)
        ddmonyy = expiry_to_ddmonyy(expiry_yyyymmdd)
        suffix = ce_or_pe == :ce ? 'CE' : 'PE'
        "#{underlying.to_s.upcase}#{ddmonyy}#{strike.to_i}#{suffix}"
      end

      def expiry_to_ddmonyy(expiry_yyyymmdd)
        date = Date.parse(expiry_yyyymmdd.to_s)
        day = date.day.to_s.rjust(2, '0')
        mon = date.strftime('%b').upcase
        year = date.strftime('%y')
        "#{day}#{mon}#{year}"
      end
    end
  end
end
