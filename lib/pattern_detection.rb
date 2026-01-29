# frozen_string_literal: true

# Executable pattern detection: global filters + H&S, double top/bottom, triangles, flags, engulfing.
# Rulebook (theory → execution): docs/pattern_detection_rulebook.md.
# Algo + index volume: docs/pattern_detection_algo.md. Checklist: lib/chart_patterns_rules.rb.
#
# Usage:
#   require_relative 'lib/pattern_detection'
#   result = PatternDetection::Pipeline.new(
#     candles_60m: candles_60m,
#     candles_15m: candles_15m,
#     candles_5m: candles_5m,
#     iv_percentile: 50,
#     days_to_expiry: 3
#   ).run
#   # result[:context_passed], result[:signals]
#
require_relative 'pattern_detection/candle_series'
require_relative 'pattern_detection/volume_metrics'
require_relative 'pattern_detection/market_context'
require_relative 'pattern_detection/head_and_shoulders'
require_relative 'pattern_detection/double_top_bottom'
require_relative 'pattern_detection/triangles'
require_relative 'pattern_detection/flag_pennant'
require_relative 'pattern_detection/engulfing'
require_relative 'pattern_detection/fib_confluence'
require_relative 'pattern_detection/mtf_filter'
require_relative 'pattern_detection/options_filter'
require_relative 'pattern_detection/pipeline'
