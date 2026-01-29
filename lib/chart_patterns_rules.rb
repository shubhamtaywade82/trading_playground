# frozen_string_literal: true

# Algo-friendly rules and tier list for chart pattern detection.
# Full reference: docs/chart_patterns_reference.md
# Use with SMC (lib/smc.rb) for swing high/low and structure.
module ChartPatternsRules
  # Five-step checklist: if any step is missing, pattern is invalid.
  ALGO_CHECKLIST = %w[
    swing_high_low_detection
    trend_validation
    geometry_rules
    volume_confirmation
    breakout_candle_close
  ].freeze

  # Tier-1: high reliability, algo-friendly.
  TIER_1 = %w[
    head_and_shoulders
    inverse_head_and_shoulders
    double_top
    double_bottom
    ascending_triangle
    descending_triangle
    symmetrical_triangle
    flag
    pennant
    engulfing_at_levels
  ].freeze

  # Tier-2: contextual.
  TIER_2 = %w[
    rectangle
    fib_confluence
    morning_star
    evening_star
  ].freeze

  # Tier-3: manual / discretionary.
  TIER_3 = %w[
    elliott_wave
    rounding_top
    rounding_bottom
  ].freeze

  module_function

  def valid?(checklist_result)
    return false unless checklist_result.is_a?(Hash)

    ALGO_CHECKLIST.all? { |step| checklist_result[step] != false }
  end

  def tier(name)
    sym = name.to_s.downcase.gsub(/\s+/, '_')
    return 1 if TIER_1.include?(sym)
    return 2 if TIER_2.include?(sym)
    return 3 if TIER_3.include?(sym)

    nil
  end
end
