# frozen_string_literal: true

require 'date'
require_relative '../candle'

# Fetches OHLCV candles from DhanHQ API (historical daily / intraday) and normalizes to Candle[].
# Requires DHAN_CLIENT_ID, DHAN_ACCESS_TOKEN and DhanHQ gem. Uses security_id + exchange_segment + instrument.
module CandleFetchers
  class DhanCandleFetcher
    INTERVAL = { m1: '1', m5: '5', m15: '15', m60: '60' }.freeze
    MAX_DAYS_INTRADAY = 90

    def initialize(security_id:, exchange_segment: 'NSE_EQ', instrument: 'EQUITY')
      @security_id = security_id.to_s
      @exchange_segment = exchange_segment
      @instrument = instrument
    end

    def fetch(symbol, timeframe)
      ensure_dhan_configured
      return [] unless defined?(DhanHQ)

      interval = INTERVAL[timeframe] || interval_from_timeframe(timeframe)
      if interval
        fetch_intraday(timeframe, interval)
      else
        fetch_daily
      end
    end

    private

    def fetch_intraday(timeframe, interval)
      to_date = Date.today
      from_date = to_date - MAX_DAYS_INTRADAY
      params = {
        security_id: @security_id,
        exchange_segment: @exchange_segment,
        instrument: @instrument,
        interval: interval,
        from_date: from_date.to_s,
        to_date: to_date.to_s
      }
      raw = DhanHQ::Models::HistoricalData.intraday(params)
      data = unwrap_charts_response(raw)
      arrays_to_candles(data)
    rescue StandardError
      []
    end

    def fetch_daily
      to_date = Date.today
      from_date = to_date - 365
      params = {
        security_id: @security_id,
        exchange_segment: @exchange_segment,
        instrument: @instrument,
        from_date: from_date.to_s,
        to_date: to_date.to_s
      }
      raw = DhanHQ::Models::HistoricalData.daily(params)
      data = unwrap_charts_response(raw)
      arrays_to_candles(data)
    rescue StandardError
      []
    end

    def ensure_dhan_configured
      return if @dhan_configured

      require 'dhan_hq'
      ENV['CLIENT_ID']    ||= ENV.fetch('DHAN_CLIENT_ID', nil)
      ENV['ACCESS_TOKEN'] ||= ENV.fetch('DHAN_ACCESS_TOKEN', nil)
      DhanHQ.configure_with_env
      @dhan_configured = true
    end

    def interval_from_timeframe(tf)
      INTERVAL[tf]
    end

    # API may return { data: { open: [], close: [] } } or { result: ... }. Use inner hash.
    def unwrap_charts_response(raw)
      return raw unless raw.is_a?(Hash)

      inner = raw['data'] || raw[:data] || raw['result'] || raw[:result]
      inner.is_a?(Hash) ? inner : raw
    end

    def arrays_to_candles(data)
      return [] unless data.is_a?(Hash)

      closes = data['close'] || data[:close]
      return [] unless closes.is_a?(Array) && closes.any?

      opens   = data['open'] || data[:open] || []
      highs   = data['high'] || data[:high] || []
      lows    = data['low'] || data[:low] || []
      volumes = data['volume'] || data[:volume] || []
      stamps  = data['timestamp'] || data[:timestamp] || []

      (0...closes.size).map do |i|
        Candle.new(
          timestamp: stamps[i],
          open: (opens[i] || closes[i]).to_f,
          high: (highs[i] || closes[i]).to_f,
          low: (lows[i] || closes[i]).to_f,
          close: closes[i].to_f,
          volume: (volumes[i] || 0).to_f
        )
      end
    end
  end
end
