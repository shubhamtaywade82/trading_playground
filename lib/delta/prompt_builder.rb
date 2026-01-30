# frozen_string_literal: true

# Builds the AI user prompt for Delta perpetuals (BTCUSD, ETHUSD).
# Single responsibility: assemble prompt text from symbol and data hash.
require_relative '../indicator_helpers'

module Delta
  class PromptBuilder
    class << self
      def build(symbol, data)
        sections = []
        sections << header_line(symbol)
        sections << market_line(data)
        sections << "LT (5m): RSI #{IndicatorHelpers.format_num(data[:rsi_14])} | SMA(20) #{IndicatorHelpers.format_num(data[:sma_20])} | Trend #{data[:trend]}"
        sections << "HTF (1h): #{data[:htf_trend] || '—'} (structure: #{data[:htf_structure] || '—'})"
        sections << key_levels_line(data)
        sections << "Funding: #{(data[:funding_rate].to_f * 100).round(4)}% (#{data[:funding_regime] || '—'})"
        sections << "Volatility: ATR #{IndicatorHelpers.format_num(data[:atr])} (#{data[:atr_pct]}% of price)" if data[:atr_pct]
        ob = data[:orderbook_imbalance]
        sections << "Orderbook: bid share #{ob[:imbalance_ratio]}" if ob && ob[:imbalance_ratio]
        sections << "SMC: #{data[:smc_summary] || '—'}"
        sections << (data[:pattern_summary] || 'Pattern: None')

        prompt = sections.join("\n")
        prompt += "\n\nReply in 2–4 lines. Format:\n• Bias: Long | Short | No trade\n• Reason: (one short line)\n• Action: (optional: level or wait)"
        prompt
      end

      private

      def header_line(symbol)
        "#{symbol} perpetual (futures) on Delta Exchange. Analyse for trading the perpetual, not spot."
      end

      def market_line(data)
        "Market: Mark #{IndicatorHelpers.format_num(data[:mark_price])} | Index #{IndicatorHelpers.format_num(data[:spot_price])} (ref) | OI #{data[:oi]} | Chg 24h #{data[:mark_change_24h]}%"
      end

      def key_levels_line(data)
        levels = data[:key_levels] || {}
        res = IndicatorHelpers.format_levels(levels[:resistance])
        sup = IndicatorHelpers.format_levels(levels[:support])
        "Key levels — Resistance: #{res} | Support: #{sup}"
      end
    end
  end
end
