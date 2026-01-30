# frozen_string_literal: true

# Builds the AI user prompt for Dhan options (NIFTY/SENSEX).
# Single responsibility: assemble prompt text from symbol and data hash.
require_relative '../indicator_helpers'

module Dhan
  class PromptBuilder
    class << self
      def build(symbol, data)
        pcr = pcr_from(data)
        levels = data[:key_levels] || {}
        res = IndicatorHelpers.format_levels(levels[:resistance])
        sup = IndicatorHelpers.format_levels(levels[:support])

        lines = []
        lines << data_line(symbol, data, pcr)
        lines << "Key levels — Resistance: #{res} | Support: #{sup}"
        lines << "SMC: #{data[:smc_summary] || '—'}"
        lines << (data[:pattern_summary] || 'Pattern: None')
        lines << strikes_and_hold_line(data)
        lines << ''
        lines << 'Options buying only (no selling). Reply in 2–4 lines. Format:'
        lines << '• Bias: Buy CE (bullish) | Buy PE (bearish) | No trade'
        lines << '• Reason: (one short line)'
        lines << '• Action: (optional: level or wait). When suggesting a trade, you may reference the suggested strikes and hold-until above.'
        lines.join("\n")
      end

      def strikes_and_hold_line(data)
        suggestions = data[:strike_suggestions]
        expiry = data[:nearest_expiry].to_s.strip
        strike_part = format_strike_suggestions(suggestions)
        hold_part = expiry.empty? ? '' : "Hold until: #{expiry} (expiry) or EOD / target hit."
        [strike_part, hold_part].reject(&:empty?).join(' ')
      end

      private

      def pcr_from(data)
        return 0.0 unless data[:call_oi].to_i.positive?
        data[:put_oi].to_f / data[:call_oi]
      end

      def data_line(symbol, data, pcr)
        iv_str = [data[:atm_iv_ce], data[:atm_iv_pe]].any? ? " | ATM IV CE #{IndicatorHelpers.format_num(data[:atm_iv_ce])} / PE #{IndicatorHelpers.format_num(data[:atm_iv_pe])}" : ''
        vol_str = data[:total_volume].to_i.positive? ? " | OC Vol #{data[:total_volume]}" : ''
        base = "#{symbol} options — buying only: buy CE when bullish, buy PE when bearish (PCR trend reversal, intraday)."
        base += " Data: Spot #{IndicatorHelpers.format_num(data[:spot_price])} | PCR #{IndicatorHelpers.format_num(pcr)} | RSI #{IndicatorHelpers.format_num(data[:rsi_14])} | Trend #{data[:trend]} | Chg #{data[:last_change]}%."
        base + iv_str + vol_str
      end

      def format_strike_suggestions(suggestions)
        return '' if suggestions.nil? || !suggestions.is_a?(Hash)

        ce = Array(suggestions[:ce])
        pe = Array(suggestions[:pe])
        return '' if ce.empty? && pe.empty?

        parts = []
        parts << "Suggested strikes — CE: #{ce.join(', ')}" if ce.any?
        parts << "PE: #{pe.join(', ')}" if pe.any?
        parts.join(' | ')
      end
    end
  end
end
