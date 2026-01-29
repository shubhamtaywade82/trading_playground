# frozen_string_literal: true

require_relative '../technical_indicators'
require_relative 'volume_metrics'

# Global pre-conditions: 60m trend + 15m volatility + INDEX VOLUME.
# Master volume filter: REL_VOL_15M >= 1.1. Trend only confirmed with volume + VWAP.
module PatternDetection
  class MarketContextFilter
    EMA_FAST = 50
    EMA_SLOW = 200
    ATR_PERIOD = 14
    ATR_LOOKBACK = 20
    REL_VOL_MASTER = 1.1   # TRADE_ALLOWED only if REL_VOL_15M >= 1.1
    REL_VOL_TREND = 1.2    # Trend confirmed only if REL_VOL_15M >= 1.2

    def initialize(candles_60m:, candles_15m:)
      @candles_60m = candles_60m || []
      @candles_15m = candles_15m || []
    end

    # Returns { passed:, reason:, trend_60m:, trend_confirmed:, volatility_ok:, volume_ok:, rel_vol_15m:, vwap_15m: }
    def run
      ohlcv_60 = PatternDetection::CandleSeries.ohlcv(@candles_60m)
      ohlcv_15 = PatternDetection::CandleSeries.ohlcv(@candles_15m)

      vol_15 = PatternDetection::VolumeMetrics.compute(ohlcv_15)
      vwap_15 = PatternDetection::VolumeMetrics.vwap(ohlcv_15)
      trend_60m = trend_60m_label(ohlcv_60)
      volatility_ok = volatility_ok?(ohlcv_15)
      volume_ok = (vol_15[:rel_vol] || 0) >= REL_VOL_MASTER
      trend_confirmed = trend_confirmed?(trend_60m, ohlcv_15, vol_15[:rel_vol], vwap_15)

      passed = volatility_ok && volume_ok
      reason = build_reason(volatility_ok, volume_ok, vol_15[:rel_vol])

      {
        passed: passed,
        reason: reason,
        trend_60m: trend_60m,
        trend_confirmed: trend_confirmed,
        volatility_ok: volatility_ok,
        volume_ok: volume_ok,
        rel_vol_15m: vol_15[:rel_vol],
        vwap_15m: vwap_15
      }
    end

    private

    def trend_60m_label(ohlcv)
      closes = ohlcv[:closes]
      return :neutral if closes.size < EMA_SLOW

      ema_fast = TechnicalIndicators.ema(closes, EMA_FAST)
      ema_slow = TechnicalIndicators.ema(closes, EMA_SLOW)
      return :neutral if ema_fast.nil? || ema_slow.nil?

      ema_fast > ema_slow ? :bullish : :bearish
    end

    def trend_confirmed?(trend_60m, ohlcv_15, rel_vol_15m, vwap_15)
      return false if rel_vol_15m.nil? || rel_vol_15m < REL_VOL_TREND
      return false if vwap_15.nil?
      return false if trend_60m == :neutral

      last_close = ohlcv_15[:closes]&.last
      return false if last_close.nil?

      case trend_60m
      when :bullish then last_close > vwap_15
      when :bearish then last_close < vwap_15
      else false
      end
    end

    def volatility_ok?(ohlcv)
      highs = ohlcv[:highs]
      lows = ohlcv[:lows]
      closes = ohlcv[:closes]
      return false if highs.size < ATR_PERIOD + ATR_LOOKBACK

      atr_now = TechnicalIndicators.atr(highs, lows, closes, ATR_PERIOD)
      return false if atr_now.nil?

      atr_series = atr_series(highs, lows, closes)
      return false if atr_series.size < ATR_LOOKBACK

      median = atr_series.sort[(ATR_LOOKBACK / 2)]
      atr_now > median
    end

    def atr_series(highs, lows, closes)
      len = highs.size
      return [] if len < ATR_PERIOD + 1

      (ATR_PERIOD...len).map do |i|
        TechnicalIndicators.atr(highs[0..i], lows[0..i], closes[0..i], ATR_PERIOD)
      end.compact
    end

    def build_reason(volatility_ok, volume_ok, rel_vol)
      return 'Index volume below average: REL_VOL_15M < 1.1 — no options buying' unless volume_ok
      return 'Volatility filter failed: ATR(15m) not above median' unless volatility_ok
      "OK (REL_VOL_15M=#{rel_vol})"
    end
  end
end
