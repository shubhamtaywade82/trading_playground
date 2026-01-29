# frozen_string_literal: true

# One-line chart pattern summary from candle context (60m, 15m, 5m, 1m).
# Used by generate_ai_prompt (Dhan) and generate_ai_prompt_delta (Delta) to include pattern in AI prompt.
require_relative 'patterns/base_pattern'
require_relative 'patterns/swing_detector'
require_relative 'patterns/head_and_shoulders'
require_relative 'patterns/double_top_bottom'
require_relative 'patterns/triangle'
require_relative 'patterns/flag_pennant'
require_relative 'patterns/engulfing'
require_relative 'engine/pattern_engine'

module PatternSummary
  module_function

  # context: { candles_60m:, candles_15m:, candles_5m:, candles_1m:, support_level:, resistance_level: } (optional iv_percentile, dte)
  # Returns one-line string e.g. "Pattern: Engulfing bullish SL=24000 TP=24600" or "Pattern: None"
  def call(context)
    candles_15m = context[:candles_15m]
    candles_5m   = context[:candles_5m]
    return 'Pattern: None' if candles_15m.nil? || candles_5m.nil?
    return 'Pattern: None' if candles_15m.size < 5 || candles_5m.size < 5

    pattern = PatternEngine.run(context)
    return 'Pattern: None' unless pattern

    dir = pattern.direction.to_s.capitalize
    name = pattern.class.name.split('::').last
    sl = pattern.respond_to?(:signal) && pattern.signal && pattern.signal[:sl]
    tp = pattern.respond_to?(:signal) && pattern.signal && pattern.signal[:tp]
    parts = ["Pattern: #{name} #{dir}"]
    parts << "SL=#{sl}" if sl
    parts << "TP=#{tp}" if tp
    parts.join(' ')
  end
end
