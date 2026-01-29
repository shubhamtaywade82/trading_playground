# frozen_string_literal: true

require_relative '../../technical_indicators'
require_relative '../../smc'
require_relative '../analysis'

# Enriches market data with SMC levels, indicators, HTF trend, funding, orderbook imbalance.
# No AI; pure technical and structural context for the thinking agent.
module Delta
  module Agents
    class AnalysisAgent
      SMA_PERIOD = 20
      RSI_PERIOD = 14
      ATR_PERIOD = 14

      def enrich(market_data)
        symbol = market_data[:symbol]
        ticker = market_data[:ticker] || {}
        candles_5m = market_data[:candles_5m] || []
        candles_1h = market_data[:candles_1h] || []
        orderbook = market_data[:orderbook]

        mark_price = (ticker['mark_price'] || ticker[:mark_price]).to_f
        spot_price = (ticker['spot_price'] || ticker[:spot_price]).to_f
        funding_rate = ticker['funding_rate'] || ticker[:funding_rate] || 0
        oi = ticker['oi'] || ticker[:oi] || ticker['oi_contracts'] || '—'
        mark_change_24h = ticker['mark_change_24h'] || ticker[:mark_change_24h] || '—'

        closes = candles_5m.filter_map { |c| (c['close'] || c[:close])&.to_f }
        opens  = candles_5m.filter_map { |c| (c['open'] || c[:open])&.to_f }
        highs  = candles_5m.filter_map { |c| (c['high'] || c[:high])&.to_f }
        lows   = candles_5m.filter_map { |c| (c['low'] || c[:low])&.to_f }

        closes_1h = candles_1h.filter_map { |c| (c['close'] || c[:close])&.to_f }
        highs_1h  = candles_1h.filter_map { |c| (c['high'] || c[:high])&.to_f }
        lows_1h   = candles_1h.filter_map { |c| (c['low'] || c[:low])&.to_f }

        sma_20 = TechnicalIndicators.sma(closes, SMA_PERIOD)
        rsi_14 = TechnicalIndicators.rsi(closes, RSI_PERIOD)
        atr = TechnicalIndicators.atr(highs, lows, closes, ATR_PERIOD)
        atr_ctx = Delta::Analysis.atr_context(atr, mark_price)
        trend = trend_label(mark_price, sma_20)
        key_levels = Delta::Analysis.key_levels(highs, lows)
        funding_regime = Delta::Analysis.funding_regime(funding_rate)
        smc_summary = SMC.summary_with_components(opens, highs, lows, closes, mark_price)

        sma_1h = TechnicalIndicators.sma(closes_1h, SMA_PERIOD)
        last_close_1h = closes_1h.last
        htf_trend = Delta::Analysis.htf_trend_label(last_close_1h, sma_1h)
        htf_structure = SMC.structure_label(highs_1h, lows_1h)
        orderbook_imbalance = Delta::Analysis.orderbook_imbalance(orderbook)

        {
          symbol: symbol,
          mark_price: mark_price,
          spot_price: spot_price,
          funding_rate: funding_rate,
          oi: oi,
          mark_change_24h: mark_change_24h,
          sma_20: sma_20,
          rsi_14: rsi_14,
          trend: trend,
          atr: atr_ctx[:atr],
          atr_pct: atr_ctx[:atr_pct],
          key_levels: key_levels,
          funding_regime: funding_regime,
          smc_summary: smc_summary,
          htf_trend: htf_trend,
          htf_structure: htf_structure,
          orderbook_imbalance: orderbook_imbalance
        }
      end

      private

      def trend_label(spot, sma)
        return 'Neutral' if sma.nil?
        return 'Bullish (above SMA)' if spot > sma
        return 'Bearish (below SMA)' if spot < sma
        'Neutral'
      end
    end
  end
end
