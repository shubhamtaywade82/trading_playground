# Recommended Timeframes for Intraday Options Buying (NIFTY / SENSEX)

Two aspects matter: **chart timeframe** (candle interval for analysis) and **time of day** (when to execute).

---

## 1. Chart Timeframe for Analysis

| Timeframe | Use case | Notes |
|-----------|----------|--------|
| **5-minute** | Aggressive, quick trades; many signals. | Aligns with OI/PCR updates every 5–15 min. Good for 5–10 trades/day and 20–50 pt moves. Noisier; needs experience to filter. |
| **15-minute** | **Sweet spot** for most intraday index options. | Less noise, clearer trends and S/R. Good for reversal patterns (e.g. engulfing) and choppy days. Use for trend, then 5-min for entry. |
| 1-minute | Ultra-short scalps only. | Very noisy; high false signals. |
| 30/60-minute | Positional intraday. | Fewer, slower signals; less suited to pure options buying. |

**Multi-timeframe:** Prefer 15-min for trend (e.g. above EMA/SMA), then 5-min for entry. For 20k capital targeting ~5k/day, starting with 15-min can limit to 3–5 higher-quality trades and reduce overtrading.

---

## 2. Time of Day for Executing Trades

- **Session:** 9:15 AM – 3:30 PM IST.
- **Avoid:** First 15–30 min (opening volatility).
- **Prime window:** **10:15 AM – 2:30 PM** — initial chaos settles, trends and liquidity are better.
- **Exit:** Square off by **3:00 PM** to avoid time-decay spikes and expiry volatility.

---

## 3. Relation to This Repo

- **Strategy:** [PCR Trend Reversal](pcr_trend_reversal_strategy.md) uses **5-min** charts on the underlying and OI/PCR updates every 5 min.
- **Script:** `generate_ai_prompt.rb` fetches 5-min intraday data and SMA/RSI; you can add 15-min data or multi-timeframe logic later if needed.
- **Session:** Strategy already restricts entry to 9:45 AM – 2:30 PM; align runs with the prime window when running the script in a loop.

Adapt to conditions: shorter charts on trending days, longer on choppy days; backtest on historical data where possible.
