# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative '../client'

# Places or cancels orders on Delta Exchange only when LIVE_TRADING=1 and client is authenticated.
# Logs every intent and result; uses correlation_id for traceability.
module Delta
  module Agents
    class ExecutionAgent
      INTENT_LOG = 'log/delta_execution_intent.jsonl'
      RESULT_LOG = 'log/delta_execution_result.jsonl'

      def initialize(client: nil)
        @client = client || DeltaExchangeClient.new
      end

      def live_trading?
        ENV.fetch('LIVE_TRADING', '0').strip == '1'
      end

      def execute(symbol, verdict, risk, context)
        return log_intent_only(symbol, verdict, risk, context, reason: 'LIVE_TRADING not set') unless live_trading?
        return log_intent_only(symbol, verdict, risk, context, reason: 'Delta API not authenticated') unless @client.authenticated?
        return log_intent_only(symbol, verdict, risk, context, reason: 'No trade bias') unless trade_bias?(verdict[:bias])

        place_or_skip(symbol, verdict, risk, context)
      end

      private

      def trade_bias?(bias)
        b = bias.to_s.strip.downcase
        b == 'long' || b == 'short'
      end

      def place_or_skip(symbol, verdict, risk, context)
        correlation_id = "delta_#{symbol}_#{Time.now.to_i}_#{rand(1000)}"
        size = position_size_contracts(context, risk)
        if size.nil? || size <= 0
          reason = ENV['DELTA_MAX_POSITION_USD'].to_s.strip.empty? ? 'Set DELTA_MAX_POSITION_USD for live sizing' : 'Size zero or negative'
          return log_intent_only(symbol, verdict, risk, context, reason: reason)
        end

        side = verdict[:bias].to_s.strip.downcase == 'long' ? 'buy' : 'sell'
        limit_price = limit_from_mark(context[:mark_price], side)

        log_intent(symbol, verdict, risk, context, correlation_id: correlation_id, side: side, size: size, limit_price: limit_price)

        order = @client.place_order(
          product_symbol: symbol,
          size: size,
          side: side,
          order_type: 'limit_order',
          limit_price: limit_price,
          time_in_force: 'gtc',
          client_order_id: correlation_id
        )
        log_result(correlation_id, symbol, order, success: true)
        { placed: true, order: order, correlation_id: correlation_id }
      rescue StandardError => e
        log_result(correlation_id, symbol, { error: e.message }, success: false)
        { placed: false, error: e.message, correlation_id: correlation_id }
      end

      def position_size_contracts(context, risk)
        max_usd = ENV['DELTA_MAX_POSITION_USD']&.strip&.to_f
        return 0 if max_usd.nil? || max_usd <= 0

        fraction = risk[:size_fraction].to_f
        fraction = 0.02 if fraction <= 0
        wallet = fetch_wallet_balance_usd
        equity = wallet.positive? ? wallet : (max_usd / fraction)
        notional = (equity * fraction).clamp(0, max_usd)
        mark = context[:mark_price].to_f
        return 0 if mark <= 0

        (notional / mark).floor
      end

      def fetch_wallet_balance_usd
        resp = @client.wallet_balances
        result = resp.is_a?(Hash) ? (resp['result'] || resp) : {}
        balances = result['available_balance'] || result[:available_balance] || []
        usd = balances.find { |b| (b['asset_symbol'] || b[:asset_symbol]) == 'USDT' }
        (usd && (usd['available'] || usd[:available])) ? (usd['available'] || usd[:available]).to_f : 0
      rescue StandardError
        0
      end

      def limit_from_mark(mark_price, side)
        mark = mark_price.to_f
        return mark if mark <= 0
        skew = mark * 0.001
        side.to_s == 'buy' ? (mark - skew).round(2) : (mark + skew).round(2)
      end

      def log_intent_only(symbol, verdict, risk, context, reason:)
        log_intent(symbol, verdict, risk, context, skip_reason: reason)
        { placed: false, skip_reason: reason }
      end

      def log_intent(symbol, verdict, risk, context, correlation_id: nil, side: nil, size: nil, limit_price: nil, skip_reason: nil)
        return unless ENV.fetch('DELTA_LOG_ACTIONS', '1').strip == '1'

        dir = File.join(File.dirname(__dir__, 2), 'log')
        FileUtils.mkdir_p(dir)
        path = File.join(dir, INTENT_LOG.split('/').last)
        record = {
          at: Time.now.utc.iso8601(3),
          symbol: symbol,
          bias: verdict[:bias],
          conviction: verdict[:conviction],
          mark_price: context[:mark_price],
          size_fraction: risk[:size_fraction],
          stop_loss: risk[:stop_loss],
          take_profit: risk[:take_profit],
          correlation_id: correlation_id,
          side: side,
          size: size,
          limit_price: limit_price,
          skip_reason: skip_reason
        }
        File.open(path, 'a') { |f| f.puts(record.to_json) }
      end

      def log_result(correlation_id, symbol, payload, success:)
        dir = File.join(File.dirname(__dir__, 2), 'log')
        FileUtils.mkdir_p(dir)
        path = File.join(dir, RESULT_LOG.split('/').last)
        record = {
          at: Time.now.utc.iso8601(3),
          correlation_id: correlation_id,
          symbol: symbol,
          success: success,
          payload: payload
        }
        File.open(path, 'a') { |f| f.puts(record.to_json) }
      end
    end
  end
end
