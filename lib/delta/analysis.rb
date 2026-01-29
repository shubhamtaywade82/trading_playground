# frozen_string_literal: true

require_relative '../smc'

# Institutional-style analysis for Delta perpetuals: key levels, funding regime, volatility, orderbook.
# Composes SMC and ticker data into a structured view for reports and AI prompts.
module Delta
  module Analysis
    module_function

    # Funding rate thresholds (decimal): beyond these we consider funding "elevated".
    FUNDING_ELEVATED = 0.0001 # 0.01%

    def key_levels(highs, lows)
      return { resistance: [], support: [], fvg_bull: [], fvg_bear: [] } if highs.nil? || lows.nil?

      sh = SMC.swing_highs(highs)
      sl = SMC.swing_lows(lows)
      fvg = SMC.fair_value_gaps(highs, lows)

      resistance = sh.last(3).reverse
      support = sl.last(3).reverse
      fvg_bull = fvg[:bullish].last(2).map { |g| [g[:gap_low], g[:gap_high]] }
      fvg_bear = fvg[:bearish].last(2).map { |g| [g[:gap_low], g[:gap_high]] }

      { resistance: resistance, support: support, fvg_bull: fvg_bull, fvg_bear: fvg_bear }
    end

    def funding_regime(funding_rate)
      rate = funding_rate.to_f
      return 'Neutral' if rate.abs < FUNDING_ELEVATED
      return 'Elevated (longs pay)' if rate.positive?
      return 'Elevated (shorts pay)' if rate.negative?

      'Neutral'
    end

    def atr_context(atr, mark_price)
      return { atr: nil, atr_pct: nil } if atr.nil? || mark_price.nil? || mark_price.zero?

      atr_pct = (atr / mark_price * 100).round(2)
      { atr: atr.round(2), atr_pct: atr_pct }
    end

    # Delta orderbook result: { "buy" => [...], "sell" => [...] } with price, size.
    # Returns { bid_vol: Float, ask_vol: Float, imbalance_ratio: Float } or nil.
    def orderbook_imbalance(orderbook_result)
      return nil if orderbook_result.nil?

      result = orderbook_result.is_a?(Hash) ? orderbook_result['result'] : orderbook_result
      return nil if result.nil?

      buys = result['buy'] || result[:buy] || []
      sells = result['sell'] || result[:sell] || []
      bid_vol = Array(buys).sum { |b| (b['size'] || b[:size] || 0).to_f }
      ask_vol = Array(sells).sum { |s| (s['size'] || s[:size] || 0).to_f }
      total = bid_vol + ask_vol
      return { bid_vol: bid_vol, ask_vol: ask_vol, imbalance_ratio: 0.5 } if total.zero?

      ratio = (bid_vol / total).round(3)
      { bid_vol: bid_vol.round(2), ask_vol: ask_vol.round(2), imbalance_ratio: ratio }
    end

    def htf_trend_label(close, sma)
      return '—' if sma.nil?
      return 'Bullish' if close > sma
      return 'Bearish' if close < sma

      'Neutral'
    end
  end
end
