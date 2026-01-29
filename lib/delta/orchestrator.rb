# frozen_string_literal: true

require_relative 'agents'
require_relative 'format_report'
require_relative 'action_logger'
require_relative 'pipeline_logger'
require_relative 'client'

# Runs the trading pipeline: MarketData → Analysis → Thinking → Risk → (optional) Execution.
# Dry-run by default; set LIVE_TRADING=1 and Delta API credentials for real orders.
module Delta
  class Orchestrator
    def initialize(
      market_data_agent: nil,
      analysis_agent: nil,
      thinking_agent: nil,
      risk_agent: nil,
      execution_agent: nil
    )
      @market_data = market_data_agent || Agents::MarketDataAgent.new
      @analysis = analysis_agent || Agents::AnalysisAgent.new
      @thinking = thinking_agent || Agents::ThinkingAgent.new
      @risk = risk_agent || Agents::RiskAgent.new
      @execution = execution_agent || Agents::ExecutionAgent.new
    end

    def run_cycle(symbols: nil)
      symbols = symbols || delta_symbols
      symbols.each do |symbol|
        run_for_symbol(symbol)
      rescue StandardError => e
        warn "Error for #{symbol}: #{e.message}"
      end
    end

    def run_for_symbol(symbol)
      market_data = @market_data.fetch(symbol)
      context = @analysis.enrich(market_data)
      verdict = @thinking.think(context)
      risk = @risk.suggest(context, verdict)
      exec_result = @execution.execute(symbol, verdict, risk, context)

      report_and_log(symbol, market_data: market_data, context: context, verdict: verdict, risk: risk, exec_result: exec_result)
      exec_result
    end

    private

    def delta_symbols
      raw = ENV.fetch('DELTA_SYMBOLS', nil)
      list = raw&.split(',')&.map(&:strip)&.reject(&:empty?)
      list&.any? ? list : %w[BTCUSD ETHUSD]
    end

    def report_and_log(symbol, market_data:, context:, verdict:, risk:, exec_result:)
      ai_response = verdict[:raw].to_s
      puts FormatDeltaReport.format_console(symbol, context, ai_response)
      append_verdict_to_console(verdict, risk, exec_result)
      puts "  Pipeline: MarketData → Analysis → Thinking → Risk → Execution"
      DeltaActionLogger.log(symbol, context, ai_response)
      Delta::PipelineLogger.log(symbol, market_data: market_data, context: context, verdict: verdict, risk: risk, exec_result: exec_result)
      send_telegram_if_configured(symbol, context, ai_response)
    end

    def append_verdict_to_console(verdict, risk, exec_result)
      puts "  Conviction: #{verdict[:conviction] || '—'}"
      puts "  Risk: size_fraction=#{risk[:size_fraction]}, SL=#{risk[:stop_loss]}, TP=#{risk[:take_profit]}"
      if exec_result[:placed]
        puts "  Execution: placed order #{exec_result[:correlation_id]}"
      elsif exec_result[:skip_reason]
        puts "  Execution: skipped — #{exec_result[:skip_reason]}"
      end
      puts "  #{FormatDeltaReport::RULER_HEAVY}"
    end

    def send_telegram_if_configured(symbol, context, ai_response)
      return unless ENV['TELEGRAM_CHAT_ID']

      require_relative '../telegram_notifier'
      TelegramNotifier.send_message(FormatDeltaReport.format_telegram(symbol, context, ai_response))
    rescue StandardError => e
      warn "Telegram send failed: #{e.message}"
    end
  end
end
