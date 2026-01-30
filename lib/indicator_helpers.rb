# frozen_string_literal: true

# Shared helpers for prompts and indicators (Dhan + Delta).
# Single place for trend label and numeric/level formatting used in AI prompts.
module IndicatorHelpers
  module_function

  def trend_label(spot, sma)
    return 'Neutral' if sma.nil?
    return 'Bullish (above SMA)' if spot > sma
    return 'Bearish (below SMA)' if spot < sma
    'Neutral'
  end

  def format_num(value)
    value.is_a?(Numeric) ? value.round(2) : value
  end

  def format_levels(arr)
    return '—' unless arr.is_a?(Array) && arr.any?
    arr.map { |x| format_num(x) }.join(', ')
  end
end
