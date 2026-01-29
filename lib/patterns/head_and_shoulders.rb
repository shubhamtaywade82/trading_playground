# frozen_string_literal: true

require_relative 'base_pattern'
require_relative 'swing_detector'

class HeadAndShoulders < BasePattern
  SYMMETRY_TOLERANCE = 0.03

  def initialize(candles_15m, candles_5m)
    super()
    @candles_15m = candles_15m
    @candles_5m  = candles_5m
  end

  def valid?
    swings = SwingDetector.detect(@candles_15m)
    highs = swings.select { |s| s[:type] == :high }.last(3)
    lows  = swings.select { |s| s[:type] == :low }.last(2)
    return false unless highs.size == 3 && lows.size == 2

    ls   = highs[0]
    head = highs[1]
    rs   = highs[2]
    low1 = lows[0]
    low2 = lows[1]

    idx = ->(s) { @candles_15m.index(s[:candle]) }
    return false unless idx[low1] > idx[ls] && idx[low1] < idx[head]
    return false unless idx[low2] > idx[head] && idx[low2] < idx[rs]

    return false unless head[:price] > ls[:price]
    return false unless rs[:price] < head[:price]
    return false unless (ls[:price] - rs[:price]).abs / head[:price] < SYMMETRY_TOLERANCE

    neckline = [low1[:price], low2[:price]].min
    return false if @candles_5m.nil? || @candles_5m.empty?

    breakdown = @candles_5m.last.close < neckline
    @signal = { neckline: neckline, sl: rs[:candle].high, head: head[:price] } if breakdown
    breakdown
  end

  def direction
    :bearish
  end
end
