# frozen_string_literal: true

require 'csv'
require_relative 'candle'

# Load candles by symbol and timeframe. No globals, no magic.
# data/candles/{symbol}_1m.csv etc. or pass arrays from fetcher.
module CandleSeries
  SUFFIX = { m1: '1m', m5: '5m', m15: '15m', m60: '60m' }.freeze

  def self.load(symbol, timeframe)
    path = path_for(symbol, timeframe)
    return from_csv(path) if path && File.file?(path)

    []
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
