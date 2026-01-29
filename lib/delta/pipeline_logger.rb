# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative 'analysis'

# Logs pipeline stage inputs/outputs per symbol per cycle to log/delta_pipeline.jsonl.
# Enable with DELTA_LOG_PIPELINE=1 (default: 1). One JSON line per symbol per run.
module Delta
  module PipelineLogger
    module_function

    def log_dir
      File.join(File.dirname(__dir__, 2), 'log')
    end

    def log_path
      File.join(log_dir, 'delta_pipeline.jsonl')
    end

    def enabled?
      ENV.fetch('DELTA_LOG_PIPELINE', '1').strip != '0'
    end

    def log(symbol, market_data:, context:, verdict:, risk:, exec_result:)
      return unless enabled?

      record = {
        at: Time.now.utc.iso8601(3),
        symbol: symbol,
        pipeline: {
          market_data: stage_market_data(symbol, market_data),
          analysis: stage_analysis(market_data, context),
          thinking: stage_thinking(context, verdict),
          risk: stage_risk(context, verdict, risk),
          execution: stage_execution(symbol, verdict, risk, context, exec_result)
        }
      }
      FileUtils.mkdir_p(log_dir)
      File.open(log_path, 'a') { |f| f.puts(record.to_json) }
    end

    def stage_market_data(symbol, market_data)
      ticker = market_data[:ticker] || {}
      out = {
        symbol: symbol,
        ticker: {
          mark_price: (ticker['mark_price'] || ticker[:mark_price])&.to_f,
          spot_price: (ticker['spot_price'] || ticker[:spot_price])&.to_f,
          funding_rate: ticker['funding_rate'] || ticker[:funding_rate],
          oi: ticker['oi'] || ticker[:oi],
          mark_change_24h: ticker['mark_change_24h'] || ticker[:mark_change_24h]
        },
        candles_5m_count: Array(market_data[:candles_5m]).size,
        candles_1h_count: Array(market_data[:candles_1h]).size
      }
      ob = Delta::Analysis.orderbook_imbalance(market_data[:orderbook]) if market_data[:orderbook]
      out[:orderbook_imbalance] = ob&.slice(:bid_vol, :ask_vol, :imbalance_ratio) if ob
      { in: { symbol: symbol }, out: out }
    end

    def stage_analysis(market_data, context)
      {
        in: { symbol: market_data[:symbol], candles_5m_count: Array(market_data[:candles_5m]).size },
        out: context.slice(
          :symbol, :mark_price, :spot_price, :funding_rate, :oi, :mark_change_24h,
          :sma_20, :rsi_14, :trend, :atr, :atr_pct,
          :key_levels, :funding_regime, :smc_summary, :htf_trend, :htf_structure,
          :orderbook_imbalance
        )
      }
    end

    def stage_thinking(context, verdict)
      {
        in: context.slice(:symbol, :mark_price, :rsi_14, :sma_20, :trend, :htf_trend, :htf_structure, :key_levels),
        out: verdict.slice(:bias, :reason, :action, :conviction, :levels)
      }
    end

    def stage_risk(context, verdict, risk)
      {
        in: {
          symbol: context[:symbol],
          mark_price: context[:mark_price],
          atr: context[:atr],
          key_levels: context[:key_levels],
          verdict_bias: verdict[:bias],
          verdict_conviction: verdict[:conviction]
        },
        out: risk
      }
    end

    def stage_execution(symbol, verdict, risk, context, exec_result)
      {
        in: {
          symbol: symbol,
          bias: verdict[:bias],
          size_fraction: risk[:size_fraction],
          stop_loss: risk[:stop_loss],
          take_profit: risk[:take_profit],
          mark_price: context[:mark_price]
        },
        out: exec_result.slice(:placed, :skip_reason, :correlation_id, :error)
      }
    end
  end
end
