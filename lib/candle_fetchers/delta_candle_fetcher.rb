# frozen_string_literal: true

require_relative '../candle'
require_relative '../delta/client'

# Fetches OHLCV candles from Delta Exchange (India) API and normalizes to Candle[].
# Uses public GET /v2/history/candles (no auth). Resolutions: 1m, 5m, 15m, 1h.
module CandleFetchers
  class DeltaCandleFetcher
    RESOLUTION = { m1: '1m', m5: '5m', m15: '15m', m60: '1h' }.freeze
    DEFAULT_BARS_60M = 500
    DEFAULT_BARS_15M = 600
    DEFAULT_BARS_5M = 800
    DEFAULT_BARS_1M = 1000

    def initialize(client: nil)
      @client = client || DeltaExchangeClient.new
    end

    def fetch(symbol, timeframe)
      resolution = RESOLUTION[timeframe] || resolution_from_timeframe(timeframe)
      return [] if resolution.nil?

      end_ts = Time.now.to_i
      start_ts = end_ts - duration_seconds(timeframe)
      raw = @client.candles(symbol: symbol, start_ts: start_ts, end_ts: end_ts, resolution: resolution)
      list = raw.is_a?(Hash) ? raw['result'] : nil
      return [] unless list.is_a?(Array) && list.any?

      list.map { |row| row_to_candle(row) }
    end

    private

    def duration_seconds(timeframe)
      bars = case timeframe
             when :m60 then DEFAULT_BARS_60M
             when :m15 then DEFAULT_BARS_15M
             when :m5  then DEFAULT_BARS_5M
             when :m1  then DEFAULT_BARS_1M
             else 500
             end
      res_min = resolution_minutes(timeframe)
      bars * res_min * 60
    end

    def resolution_minutes(timeframe)
      case timeframe
      when :m60 then 60
      when :m15 then 15
      when :m5  then 5
      when :m1  then 1
      else 5
      end
    end

    def resolution_from_timeframe(tf)
      RESOLUTION[tf]
    end

    def row_to_candle(row)
      h = row.is_a?(Hash) ? row : {}
      ts = h['time'] || h[:time]
      Candle.new(
        timestamp: ts,
        open: (h['open'] || h[:open]).to_f,
        high: (h['high'] || h[:high]).to_f,
        low: (h['low'] || h[:low]).to_f,
        close: (h['close'] || h[:close]).to_f,
        volume: (h['volume'] || h[:volume]).to_f
      )
    end
  end
end
