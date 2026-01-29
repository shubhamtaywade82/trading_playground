# SMC parameters — window and candles per timeframe

How **Smart Money Concepts** (SMC) is parameterised and on how many candles it runs in each script.

---

## Parameters (in `lib/smc.rb`)

| Parameter | Value | Meaning |
|-----------|--------|--------|
| **Swing high / swing low** | `window: 2` | A bar is a swing high if its high is ≥ all highs in `[i-2, i+2]` (2 bars each side). Same for swing low with lows. Minimum candles needed: **5** (`(window*2)+1`). |
| **Fair value gaps (FVG)** | `lookback: 10` | Scans the last **10** overlapping 3-candle triplets for bullish/bearish FVGs. Returns the last 2 of each type. Minimum candles: **12** (10 triplets + 2). |
| **Structure (HH/HL, LH/LL)** | `min_swings: 2` | Needs at least **2** swing highs and **2** swing lows. Uses the same `window: 2` for swings. |

These are fixed in code. `fair_value_gaps` accepts `lookback:`; `swing_highs` / `swing_lows` accept `window:` if you call them with kwargs.

---

## Timeframes and candle counts per script

### Dhan — `generate_ai_prompt.rb`

| What | Timeframe | How many candles |
|------|-----------|-------------------|
| RSI, SMA, trend, last_change | **5m** | **from_date < to_date**: last **DHAN_INTRADAY_DAYS** (default **5**) days. One request; typically ~5 × ~75 = **~375** bars (5 days × ~75 bars/day). |
| SMC summary + key levels | **15m** | Same range (from_date to to_date). Typically ~5 × ~25 = **~125** bars (5 days × ~25 bars/day). |

`from_date` and `to_date` are always different: `from_date = to_date - DHAN_INTRADAY_DAYS`, `to_date = today`. SMC uses **summary_with_components** so at least one of structure (HH/HL, LH/LL), FVG, or key levels (R/S) is always present.

---

### Delta — `generate_ai_prompt_delta.rb` and `run_delta_live.rb`

| What | Timeframe | How many candles | Env (default) |
|------|-----------|-------------------|----------------|
| SMC summary + key levels | **5m** | Last **120 minutes** → **24** x 5m bars | `DELTA_LOOKBACK_MINUTES=120` |
| HTF structure (HH/HL, LH/LL) | **1h** | Last **24 hours** → **24** x 1h bars | `DELTA_HTF_LOOKBACK_HOURS=24` |

- **5m:** Used for `SMC.summary`, `Delta::Analysis.key_levels` (swing highs/lows + FVG), and LT trend/RSI/SMA.
- **1h:** Used only for `SMC.structure_label(highs_1h, lows_1h)` (HTF structure in the report).

---

## Summary

| Script | SMC on 5m | SMC on 15m | SMC on 1h | 5m candles | 15m candles | 1h candles |
|--------|-----------|------------|-----------|------------|-------------|------------|
| **Dhan** (`generate_ai_prompt`) | No (used for RSI/SMA/trend) | Yes (summary + key levels) | No | ~375 (5 days) | ~125 (5 days) | — |
| **Delta** (`generate_ai_prompt_delta`, `run_delta_live`) | Yes (summary + key levels) | No | Yes (structure only) | 24 (120 min) | — | 24 (24 h) |

**Window:** 2 bars each side for swings. **FVG lookback:** 10 triplets. **Dhan:** `from_date` &lt; `to_date` (default 5 days); at least one SMC component (HH/HL, FVG, or R/S) always included.
