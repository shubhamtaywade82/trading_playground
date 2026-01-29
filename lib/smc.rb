# frozen_string_literal: true

# Smart Money Concepts (SMC) from OHLC: fair value gaps (FVG) and market structure (HH/HL, LH/LL).
# Operates on arrays: opens, highs, lows, closes (oldest first).
#
# Parameters (fixed in code; override by passing kwargs where supported):
#   Swing high/low: window = 2 (2 bars each side; bar at i must be extreme in [i-2..i+2]). Min candles = 5.
#   FVG: lookback = 10 (scan last 10 overlapping 3-candle triplets; returns last 2 bullish + last 2 bearish).
#   Structure: min_swings = 2 (needs at least 2 swing highs and 2 swing lows for HH/HL or LH/LL).
#
# Where SMC is run and candle count:
#   Dhan (generate_ai_prompt): 5m for RSI/SMA/trend; 15m for SMC + key levels. from_date < to_date (DHAN_INTRADAY_DAYS, default 5). ~5 days 5m + 15m in one request.
#   Delta (generate_ai_prompt_delta, run_delta_live): 5m for summary + key_levels — DELTA_LOOKBACK_MINUTES (default 120) → 24 bars. 1h for structure_label only — DELTA_HTF_LOOKBACK_HOURS (default 24) → 24 bars.
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

  # Swing highs with bar index: [{ index: i, value: high }, ...]. For volume/RSI at swing.
  def swing_highs_with_index(highs, window: 2)
    return [] if highs.nil? || highs.size < (window * 2) + 1

    (window...(highs.size - window)).filter_map do |i|
      mid = highs[i]
      next nil unless (i - window..i + window).all? { |j| j == i || highs[j] <= mid }

      { index: i, value: mid }
    end
  end

  # Swing lows with bar index: [{ index: i, value: low }, ...].
  def swing_lows_with_index(lows, window: 2)
    return [] if lows.nil? || lows.size < (window * 2) + 1

    (window...(lows.size - window)).filter_map do |i|
      mid = lows[i]
      next nil unless (i - window..i + window).all? { |j| j == i || lows[j] >= mid }

      { index: i, value: mid }
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

  # Summary that always includes at least one component: structure (HH/HL, LH/LL), FVG, or key levels (R/S).
  # Key levels from swing highs/lows ensure we never return only "—" or "No recent FVG".
  def summary_with_components(opens, highs, lows, closes, current_price)
    return '—' if highs.nil? || highs.empty?

    fvg = fair_value_gaps(highs, lows)
    struct = structure_label(highs, lows)
    sh = swing_highs(highs)
    sl = swing_lows(lows)

    parts = []
    parts << "Structure #{struct}" if struct && struct.to_s != '—'
    fvg_parts = []
    fvg_parts << "Bullish FVG #{fvg[:bullish].last[:gap_low].round(2)}–#{fvg[:bullish].last[:gap_high].round(2)}" if fvg[:bullish].any?
    fvg_parts << "Bearish FVG #{fvg[:bearish].last[:gap_low].round(2)}–#{fvg[:bearish].last[:gap_high].round(2)}" if fvg[:bearish].any?
    parts << (fvg_parts.any? ? fvg_parts.join('; ') : 'No FVG')
    res = sh.last(3).reverse.map { |x| x.round(2) }
    sup = sl.last(3).reverse.map { |x| x.round(2) }
    parts << "R: #{res.join(',')}" if res.any?
    parts << "S: #{sup.join(',')}" if sup.any?

    parts.any? ? parts.join(' | ') : '—'
  end
end
