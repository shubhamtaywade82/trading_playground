# frozen_string_literal: true

# Normalizes Dhan charts API response to { opens:, highs:, lows:, closes: }.
# Handles both hash-of-arrays and array-of-candle-hashes.
module Dhan
  class OhlcNormalizer
    EMPTY = { opens: [], highs: [], lows: [], closes: [] }.freeze

    class << self
      def from_response(response)
        raw = extract_raw(response)
        return EMPTY if raw.nil?

        raw.is_a?(Hash) ? from_hash(raw) : from_array(raw)
      end

      private

      def extract_raw(response)
        return nil unless response
        return response['data'] || response[:data] || response if response.is_a?(Hash)
        response
      end

      def from_hash(raw)
        closes = raw['close'] || raw[:close]
        return EMPTY unless closes.is_a?(Array) && closes.any?

        n = closes.size
        closes = closes.map(&:to_f)
        opens = pad(Array(raw['open'] || raw[:open]).map(&:to_f), n, closes.first)
        highs = pad(Array(raw['high'] || raw[:high]).map(&:to_f), n, closes.first)
        lows  = pad(Array(raw['low'] || raw[:low]).map(&:to_f), n, closes.first)
        { opens: opens.first(n), highs: highs.first(n), lows: lows.first(n), closes: closes }
      end

      def from_array(raw)
        return EMPTY unless raw.is_a?(Array)

        opens  = raw.map { |c| num(c, :open) }.compact.map(&:to_f)
        highs  = raw.map { |c| num(c, :high) }.compact.map(&:to_f)
        lows   = raw.map { |c| num(c, :low) }.compact.map(&:to_f)
        closes = raw.map { |c| num(c, :close) }.compact.map(&:to_f)
        { opens: opens, highs: highs, lows: lows, closes: closes }
      end

      def pad(arr, n, fill)
        return arr if arr.size >= n
        arr.first(n).concat([fill] * (n - arr.size))
      end

      def num(candle, key)
        return nil unless candle.is_a?(Hash)
        candle[key] || candle[key.to_s]
      end
    end
  end
end
