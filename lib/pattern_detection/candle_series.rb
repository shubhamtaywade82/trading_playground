# frozen_string_literal: true

# Extracts OHLCV arrays from candle hashes. Keys: open, high, low, close, volume (string or symbol).
module PatternDetection
  module CandleSeries
    module_function

    def ohlcv(candles)
      return { opens: [], highs: [], lows: [], closes: [], volumes: [] } if candles.nil? || candles.empty?

      opens = candles.filter_map { |c| num(c, :open) }
      highs = candles.filter_map { |c| num(c, :high) }
      lows  = candles.filter_map { |c| num(c, :low) }
      closes = candles.filter_map { |c| num(c, :close) }
      volumes = candles.filter_map { |c| num(c, :volume) }
      volumes = closes.map { 0 } if volumes.size != closes.size

      { opens: opens, highs: highs, lows: lows, closes: closes, volumes: volumes }
    end

    def num(candle, key)
      v = candle[key] || candle[key.to_s]
      return nil if v.nil?
      v.to_f
    end
  end
end
