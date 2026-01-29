# frozen_string_literal: true

require 'csv'
require_relative 'candle'

# Load candles by symbol and timeframe. No globals, no magic.
# data/candles/{symbol}_1m.csv etc., or API when CANDLE_SOURCE=dhan|delta (see .env.example).
module CandleSeries
  SUFFIX = { m1: '1m', m5: '5m', m15: '15m', m60: '60m' }.freeze

  def self.load(symbol, timeframe, fetcher: nil)
    f = fetcher || fetcher_from_env
    return f.fetch(symbol, timeframe) if f

    path = path_for(symbol, timeframe)
    return from_csv(path) if path && File.file?(path)

    []
  end

  def self.fetcher_from_env
    source = ENV['CANDLE_SOURCE']&.strip&.downcase
    return nil if source.nil? || source.empty?

    case source
    when 'delta'
      require_relative 'candle_fetchers/delta_candle_fetcher'
      CandleFetchers::DeltaCandleFetcher.new
    when 'dhan'
      security_id = ENV['PATTERN_SECURITY_ID'] || ENV['DHAN_SECURITY_ID']
      return nil if security_id.to_s.empty?

      require_relative 'candle_fetchers/dhan_candle_fetcher'
      CandleFetchers::DhanCandleFetcher.new(
        security_id: security_id,
        exchange_segment: ENV['PATTERN_EXCHANGE_SEGMENT'] || 'NSE_EQ',
        instrument: ENV['PATTERN_INSTRUMENT'] || 'EQUITY'
      )
    else
      nil
    end
  end

  def self.from_csv(path)
    candles = []
    CSV.foreach(path, headers: true) do |row|
      candles << Candle.from_hash(
        timestamp: row['timestamp'],
        open: row['open'],
        high: row['high'],
        low: row['low'],
        close: row['close'],
        volume: row['volume']
      )
    end
    candles
  end

  def self.from_ohlcv_arrays(opens:, highs:, lows:, closes:, volumes: nil)
    return [] if closes.nil? || closes.empty?

    volumes = closes.map { 0 } if volumes.nil? || volumes.size != closes.size
    (0...closes.size).map do |i|
      Candle.new(
        timestamp: nil,
        open: opens[i].to_f,
        high: highs[i].to_f,
        low: lows[i].to_f,
        close: closes[i].to_f,
        volume: volumes[i].to_f
      )
    end
  end

  def self.path_for(symbol, timeframe)
    base = File.join(File.dirname(__dir__), 'data', 'candles')
    suffix = SUFFIX[timeframe] || timeframe.to_s
    File.join(base, "#{symbol}_#{suffix}.csv")
  end
end
