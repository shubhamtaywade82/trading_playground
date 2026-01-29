# frozen_string_literal: true

require 'timeout'
require_relative '../../ai_caller'
require_relative '../action_logger'

# Professional futures trader lens: builds a focused prompt and parses structured verdict from Ollama.
# Prefer Ollama for speed; structured output (Bias, Reason, Action, Conviction). Safe fallback on timeout/error.
module Delta
  module Agents
    class ThinkingAgent
      DEFAULT_AI_TIMEOUT = 25
      SYSTEM_PROMPT = <<~PROMPT.strip
        You are a professional futures trader. Use only the data below. Reply in exactly this format:
        Bias: Long | Short | No trade
        Reason: (one short line)
        Action: (level or wait)
        Conviction: High | Medium | Low
      PROMPT

      def initialize(ai_caller: nil)
        @ai_caller = ai_caller || AiCaller
      end

      def think(context)
        prompt = build_prompt(context)
        provider = ENV['AI_PROVIDER']&.strip&.downcase
        provider = 'ollama' unless %w[openai ollama].include?(provider)
        model = ENV['AI_MODEL']&.strip
        model = nil if model&.empty?
        timeout_sec = ENV['DELTA_AI_TIMEOUT']&.strip&.to_i
        timeout_sec = DEFAULT_AI_TIMEOUT if timeout_sec.nil? || timeout_sec <= 0

        raw = call_ai_with_timeout(prompt, provider, model, timeout_sec)
        parse_verdict(raw.to_s.strip, context[:symbol])
      rescue StandardError => e
        warn "ThinkingAgent: #{e.message}"
        safe_fallback_verdict(e.message)
      end

      private

      def call_ai_with_timeout(prompt, provider, model, timeout_sec)
        Timeout.timeout(timeout_sec) do
          ollama_timeout = provider == 'ollama' ? timeout_sec : nil
          @ai_caller.call(prompt, provider: provider, model: model, timeout: ollama_timeout)
        end
      end

      def safe_fallback_verdict(reason = 'AI unavailable')
        {
          raw: "[Fallback] #{reason}",
          bias: nil,
          reason: reason,
          action: 'wait',
          conviction: 'Low',
          levels: []
        }
      end

      def build_prompt(context)
        funding_pct = (context[:funding_rate].to_f * 100).round(4)
        levels = context[:key_levels] || {}
        res = format_levels(levels[:resistance])
        sup = format_levels(levels[:support])
        ob = context[:orderbook_imbalance]

        parts = []
        parts << "#{context[:symbol]} Mark #{fmt(context[:mark_price])} | RSI #{fmt(context[:rsi_14])} | SMA20 #{fmt(context[:sma_20])} | #{context[:trend]}"
        parts << "HTF #{context[:htf_trend]} #{context[:htf_structure]} | R #{res} S #{sup}"
        parts << "Funding #{funding_pct}% #{context[:funding_regime]}"
        parts << "ATR #{fmt(context[:atr])} #{context[:atr_pct]}%" if context[:atr_pct]
        parts << "OB #{ob[:imbalance_ratio]}" if ob && ob[:imbalance_ratio]
        parts << (context[:smc_summary] || '—')

        "#{SYSTEM_PROMPT}\n\n#{parts.join("\n")}"
      end

      def format_levels(arr)
        return '—' if arr.nil? || !arr.is_a?(Array) || arr.empty?
        arr.map { |x| fmt(x) }.join(', ')
      end

      def fmt(value)
        return '—' if value.nil?
        value.is_a?(Numeric) ? value.round(2) : value.to_s
      end

      def parse_verdict(raw, symbol)
        return empty_verdict(raw) if raw.to_s.strip.empty?

        text = raw.strip
        bias = text.match(/\bBias:\s*(Long|Short|No\s*trade)/i)&.captures&.first
        reason = text.match(/\bReason:\s*(.+?)(?=\s*Action:|\s*Conviction:|\z)/im)&.captures&.first&.strip
        action = text.match(/\bAction:\s*(.+?)(?=\s*Conviction:|\z)/im)&.captures&.first&.strip
        conviction = text.match(/\bConviction:\s*(High|Medium|Low)/i)&.captures&.first
        levels = DeltaActionLogger.levels_from_action(action.to_s, symbol)

        {
          raw: raw,
          bias: bias,
          reason: reason,
          action: action,
          conviction: conviction || 'Low',
          levels: levels
        }
      end

      def empty_verdict(raw)
        { raw: raw, bias: nil, reason: nil, action: nil, conviction: 'Low', levels: [] }
      end
    end
  end
end
