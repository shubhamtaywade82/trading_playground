# frozen_string_literal: true

# Fetches and normalizes market data for one symbol from Delta Exchange.
# Single responsibility: raw ticker, candles (5m + 1h), orderbook.
module Delta
  module Agents
    class MarketDataAgent
      DEFAULT_RESOLUTION = '5m'
      DEFAULT_LOOKBACK_MINUTES = 120
      HTF_RESOLUTION = '1h'
      DEFAULT_HTF_HOURS = 24

      def initialize(client: nil, resolution: nil, lookback_minutes: nil, htf_hours: nil)
        @client = client || DeltaExchangeClient.new
        @resolution = resolution || ENV.fetch('DELTA_RESOLUTION', DEFAULT_RESOLUTION)
        @lookback_minutes = lookback_minutes || ENV.fetch('DELTA_LOOKBACK_MINUTES', DEFAULT_LOOKBACK_MINUTES.to_s).to_i
        @htf_hours = htf_hours || ENV.fetch('DELTA_HTF_LOOKBACK_HOURS', DEFAULT_HTF_HOURS.to_s).to_i
      end

      def fetch(symbol)
        end_ts = Time.now.to_i
        start_ts = end_ts - (@lookback_minutes * 60)
        start_ts_1h = end_ts - (@htf_hours * 3600)

        ticker_result = fetch_ticker(symbol)
        candles_5m = fetch_candles(symbol, @resolution, start_ts, end_ts)
        candles_1h = fetch_candles(symbol, HTF_RESOLUTION, start_ts_1h, end_ts)
        orderbook = fetch_orderbook(symbol)

        {
          symbol: symbol,
          ticker: ticker_result,
          candles_5m: candles_5m,
          candles_1h: candles_1h,
          orderbook: orderbook
        }
      end

      private

      def fetch_ticker(symbol)
        resp = @client.ticker(symbol)
        result = resp.is_a?(Hash) ? (resp['result'] || resp) : {}
        raise "Ticker failed for #{symbol}" if result.empty?
        result
      end

      def fetch_candles(symbol, resolution, start_ts, end_ts)
        resp = @client.candles(symbol: symbol, resolution: resolution, start_ts: start_ts, end_ts: end_ts)
        list = resp.is_a?(Hash) ? resp['result'] : nil
        Array(list || [])
      end

      def fetch_orderbook(symbol)
        @client.orderbook(symbol, depth: 20)
      rescue StandardError
        nil
      end
    end
  end
end
