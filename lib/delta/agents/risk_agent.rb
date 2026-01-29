# frozen_string_literal: true

require_relative '../../ai_caller'

# Suggests position size, stop-loss, and take-profit from context and verdict.
# Uses ATR for SL/TP distance; optionally asks Ollama for volatility-adjusted size.
module Delta
  module Agents
    class RiskAgent
      DEFAULT_SIZE_FRACTION = 0.02
      ATR_SL_MULTIPLIER = 1.5
      ATR_TP_MULTIPLIER = 2.5
      MAX_SIZE_FRACTION = 0.05

      def initialize(ai_caller: nil)
        @ai_caller = ai_caller || AiCaller
      end

      def suggest(context, verdict, wallet_balance_usd: nil)
        atr = context[:atr]
        mark_price = context[:mark_price]
        key_levels = context[:key_levels] || {}
        conviction = verdict[:conviction]&.downcase
        bias = verdict[:bias]&.downcase

        size_fraction = size_fraction_from_conviction(conviction)
        size_fraction = ask_ollama_size(atr, conviction, size_fraction) if use_ollama_for_size?

        stop_loss = suggest_stop_loss(bias, mark_price, atr, key_levels)
        take_profit = suggest_take_profit(bias, mark_price, atr, key_levels)

        {
          size_fraction: size_fraction.clamp(0.01, MAX_SIZE_FRACTION),
          stop_loss: stop_loss,
          take_profit: take_profit,
          atr_sl_mult: ATR_SL_MULTIPLIER,
          atr_tp_mult: ATR_TP_MULTIPLIER
        }
      end

      private

      def size_fraction_from_conviction(conviction)
        case conviction
        when 'high' then 0.03
        when 'medium' then 0.02
        when 'low' then 0.01
        else DEFAULT_SIZE_FRACTION
        end
      end

      def use_ollama_for_size?
        ENV['DELTA_OLLAMA_RISK']&.strip == '1'
      end

      def ask_ollama_size(atr, conviction, default)
        prompt = "Conviction: #{conviction}. Default size fraction: #{default}. Reply with one number 0.01 to 0.05 only."
        raw = @ai_caller.call(prompt, provider: 'ollama', model: ENV['AI_MODEL']&.strip)
        num = raw.to_s.strip[/0\.0\d+/]&.to_f
        num && num.between?(0.01, 0.05) ? num : default
      rescue StandardError
        default
      end

      def suggest_stop_loss(bias, mark_price, atr, key_levels)
        return nil unless bias && (bias == 'long' || bias == 'short')
        distance = atr ? (atr * ATR_SL_MULTIPLIER) : (mark_price * 0.02)
        nearest_support = (key_levels[:support] || []).last
        nearest_resistance = (key_levels[:resistance] || []).last

        if bias == 'long'
          level = nearest_support
          sl = level && level < mark_price ? [mark_price - distance, level].max : mark_price - distance
        else
          level = nearest_resistance
          sl = level && level > mark_price ? [mark_price + distance, level].min : mark_price + distance
        end
        sl.round(2)
      end

      def suggest_take_profit(bias, mark_price, atr, key_levels)
        return nil unless bias && (bias == 'long' || bias == 'short')
        distance = atr ? (atr * ATR_TP_MULTIPLIER) : (mark_price * 0.03)
        nearest_resistance = (key_levels[:resistance] || []).last
        nearest_support = (key_levels[:support] || []).last

        if bias == 'long'
          level = nearest_resistance
          tp = level && level > mark_price ? [mark_price + distance, level].min : mark_price + distance
        else
          level = nearest_support
          tp = level && level < mark_price ? [mark_price - distance, level].max : mark_price - distance
        end
        tp.round(2)
      end
    end
  end
end
