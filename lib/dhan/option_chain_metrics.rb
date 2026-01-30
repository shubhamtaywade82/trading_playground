# frozen_string_literal: true

# Extracts option chain data and computes metrics (PCR, ATM IV, total volume).
# Single responsibility: parse Dhan option chain response and derive metrics.
module Dhan
  class OptionChainMetrics
    class << self
      def extract(response)
        data = response.is_a?(Hash) ? (response['data'] || response) : response
        return [nil, nil] unless data

        last_price = data['last_price'] || data[:last_price]
        oc = data['oc'] || data[:oc]
        [last_price, oc]
      end

      def metrics(oc, spot_price)
        out = { call_oi: 0, put_oi: 0, atm_iv_ce: nil, atm_iv_pe: nil, total_volume: 0 }
        return out unless oc.is_a?(Hash) && spot_price.is_a?(Numeric)

        out[:call_oi] = sum_oi(oc, :call)
        out[:put_oi]  = sum_oi(oc, :put)
        set_atm_iv!(oc, spot_price, out)
        out[:total_volume] = sum_volume(oc)
        out
      end

      private

      def sum_oi(oc, side)
        key = side == :call ? 'ce' : 'pe'
        oc.sum do |_strike, row|
          next 0 unless row.is_a?(Hash)
          leg = row[key] || row[key.to_sym]
          (leg && (leg['oi'] || leg[:oi])).to_i
        end
      end

      def set_atm_iv!(oc, spot_price, out)
        strike_key = oc.keys.min_by { |k| ((k.to_s.to_f rescue 0) - spot_price).abs }
        return unless strike_key && oc[strike_key].is_a?(Hash)

        row = oc[strike_key]
        ce = row['ce'] || row[:ce]
        pe = row['pe'] || row[:pe]
        out[:atm_iv_ce] = (ce && (ce['implied_volatility'] || ce[:implied_volatility]))&.to_f
        out[:atm_iv_pe] = (pe && (pe['implied_volatility'] || pe[:implied_volatility]))&.to_f
      end

      def sum_volume(oc)
        total = 0
        oc.each do |_strike, row|
          next unless row.is_a?(Hash)
          %w[ce pe].each do |leg_key|
            leg = row[leg_key] || row[leg_key.to_sym]
            total += (leg && (leg['volume'] || leg[:volume])).to_i
          end
        end
        total
      end
    end
  end
end
