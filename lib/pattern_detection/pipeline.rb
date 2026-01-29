# frozen_string_literal: true

require_relative 'candle_series'
require_relative 'volume_metrics'
require_relative 'market_context'
require_relative 'head_and_shoulders'
require_relative 'double_top_bottom'
require_relative 'triangles'
require_relative 'flag_pennant'
require_relative 'engulfing'
require_relative 'fib_confluence'
require_relative 'mtf_filter'
require_relative 'options_filter'
require_relative 'fake_breakout_filter'
require_relative 'volume_vwap_confirmation'

# Execution pipeline: market context (incl. index volume) → pattern detection → fake breakout filter → MTF → options filter.
# OPTION_ENTRY_ALLOWED only if pattern_valid && volume_confirmation && trend_confirmation && IV/expiry/strike.
module PatternDetection
  class Pipeline
    def initialize(
      candles_60m:,
      candles_15m:,
      candles_5m:,
      candles_1m: nil,
      iv_percentile: nil,
      days_to_expiry: nil,
      strike_offset: nil,
      support_level: nil,
      resistance_level: nil,
      vwap: nil,
      fib_618: nil
    )
      @candles_60m = candles_60m || []
      @candles_15m = candles_15m || []
      @candles_5m = candles_5m || []
      @candles_1m = candles_1m || []
      @iv_percentile = iv_percentile
      @days_to_expiry = days_to_expiry
      @strike_offset = strike_offset
      @support_level = support_level
      @resistance_level = resistance_level
      @vwap = vwap
      @fib_618 = fib_618
    end

    # Returns { context_passed: bool, context_reason:, trend_60m:, signals: [ { pattern:, side:, sl:, tp:, reason: }, ... ] }
    def run
      context = MarketContextFilter.new(candles_60m: @candles_60m, candles_15m: @candles_15m).run
      unless context[:passed]
        return {
          context_passed: false,
          context_reason: context[:reason],
          trend_60m: context[:trend_60m],
          trend_confirmed: false,
          volume_ok: context[:volume_ok],
          rel_vol_15m: context[:rel_vol_15m],
          signals: []
        }
      end

      trend_60m = context[:trend_60m]
      mtf = MTFFilter.new(trend_60m: trend_60m)
      opt_filter = OptionsFilter.new(
        iv_percentile: @iv_percentile,
        days_to_expiry: @days_to_expiry,
        strike_offset: @strike_offset
      )
      opt_result = opt_filter.run

      ohlcv_5 = PatternDetection::CandleSeries.ohlcv(@candles_5m)
      fake_filter = FakeBreakoutFilter.new(ohlcv_5m: ohlcv_5)
      vwap_15 = context[:vwap_15m]
      volume_vwap = VolumeVwapConfirmation.new(ohlcv_5m: ohlcv_5, vwap: vwap_15).run

      signals = []
      detectors = build_detectors(trend_60m)
      detectors.each do |result|
        next unless result[:valid]
        next unless opt_result[:passed]
        mtf_result = mtf.allow_side(result[:side])
        next unless mtf_result[:passed]

        fake_check = fake_filter.check(price_breaks_level: true)
        next if fake_check[:fake]

        signals << {
          pattern: result[:pattern],
          side: result[:side],
          sl: result[:sl],
          tp: result[:tp],
          reason: result[:reason],
          confirm_close: result[:confirm_close]
        }
      end

      {
        context_passed: true,
        context_reason: context[:reason],
        trend_60m: trend_60m,
        trend_confirmed: context[:trend_confirmed],
        volume_ok: context[:volume_ok],
        rel_vol_15m: context[:rel_vol_15m],
        volume_vwap: volume_vwap,
        options_filter_passed: opt_result[:passed],
        options_filter_reason: opt_result[:reason],
        signals: signals
      }
    end

    private

    def build_detectors(trend_60m)
      out = []

      hs = HeadAndShoulders.new(candles_15m: @candles_15m, candles_5m: @candles_5m, trend_60m: trend_60m)
      out << hs.detect_bearish
      out << hs.detect_inverse_bullish

      dt = DoubleTopBottom.new(candles_15m: @candles_15m, candles_5m: @candles_5m, trend_60m: trend_60m)
      out << dt.detect_double_top
      out << dt.detect_double_bottom

      tri = Triangles.new(candles_15m: @candles_15m, candles_5m: @candles_5m, trend_60m: trend_60m)
      out << tri.detect_ascending
      out << tri.detect_descending

      flag = FlagPennant.new(candles_15m: @candles_15m, candles_5m: @candles_5m, candles_1m: @candles_1m, trend_60m: trend_60m)
      out << flag.detect_bullish_flag
      out << flag.detect_bearish_flag

      eng = EngulfingAtLevel.new(
        candles_5m: @candles_5m,
        support_level: @support_level,
        resistance_level: @resistance_level,
        vwap: @vwap,
        fib_618: @fib_618
      )
      out << eng.detect_bullish
      out << eng.detect_bearish

      out
    end
  end
end
