# frozen_string_literal: true

# Smart Money Concepts (SMC) from OHLC: fair value gaps (FVG) and market structure (HH/HL, LH/LL).
# Operates on arrays: opens, highs, lows, closes (oldest first).
module SMC
  module_function

  # Fair value gap: 3-candle pattern. Bullish FVG = candle1_high < candle3_low; Bearish = candle1_low > candle3_high.
  # Returns most recent FVG of each type in the last +lookback+ triplets, with gap levels.
  def fair_value_gaps(highs, lows, lookback: 10)
    return { bullish: [], bearish: [] } if highs.nil? || lows.nil? || highs.size < 3 || lows.size < 3

    bullish = []
    bearish = []
    start = [0, highs.size - lookback - 2].max
    (start..(highs.size - 3)).each do |i|
      h1 = highs[i]
      h2 = highs[i + 1]
      h3 = highs[i + 2]
      l1 = lows[i]
      l2 = lows[i + 1]
      l3 = lows[i + 2]
      bullish << { gap_low: h1, gap_high: l3 } if h1 < l3
      bearish << { gap_low: h3, gap_high: l1 } if l1 > h3
    end
    { bullish: bullish.last(2), bearish: bearish.last(2) }
  end

  # Local swing high: high greater than left and right (window 2 each side).
  def swing_highs(highs, window: 2)
    return [] if highs.nil? || highs.size < (window * 2) + 1

    (window...(highs.size - window)).filter_map do |i|
      mid = highs[i]
      next nil unless (i - window..i + window).all? { |j| j == i || highs[j] <= mid }

      mid
    end
  end

  # Local swing low: low less than left and right.
  def swing_lows(lows, window: 2)
    return [] if lows.nil? || lows.size < (window * 2) + 1

    (window...(lows.size - window)).filter_map do |i|
      mid = lows[i]
      next nil unless (i - window..i + window).all? { |j| j == i || lows[j] >= mid }

      mid
    end
  end

  # Market structure label from last swing highs/lows: HH/HL (bullish), LH/LL (bearish), or Choppy.
  def structure_label(highs, lows, min_swings: 2)
    sh = swing_highs(highs)
    sl = swing_lows(lows)
    return '—' if sh.size < min_swings || sl.size < min_swings

    h_up = sh.last(2).each_cons(2).all? { |a, b| b > a }
    h_dn = sh.last(2).each_cons(2).all? { |a, b| b < a }
    l_up = sl.last(2).each_cons(2).all? { |a, b| b > a }
    l_dn = sl.last(2).each_cons(2).all? { |a, b| b < a }

    return 'HH/HL' if h_up && l_up
    return 'LH/LL' if h_dn && l_dn

    'Choppy'
  end

  # One-line SMC summary for prompt: structure (HH/HL, LH/LL) + recent fair value gaps.
  def summary(opens, highs, lows, closes, current_price)
    return '—' if highs.nil? || highs.empty?

    fvg = fair_value_gaps(highs, lows)
    struct = structure_label(highs, lows)

    fvg_parts = []
    if fvg[:bullish].any?
      fvg_parts << "Bullish FVG #{fvg[:bullish].last[:gap_low].round(2)}–#{fvg[:bullish].last[:gap_high].round(2)}"
    end
    if fvg[:bearish].any?
      fvg_parts << "Bearish FVG #{fvg[:bearish].last[:gap_low].round(2)}–#{fvg[:bearish].last[:gap_high].round(2)}"
    end
    fvg_str = fvg_parts.any? ? fvg_parts.join('; ') : 'No recent FVG'

    "Structure #{struct} | #{fvg_str}"
  end
end
