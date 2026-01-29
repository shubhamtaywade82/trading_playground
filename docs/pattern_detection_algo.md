# Pattern Detection — Executable Logic

Strict, algo-ready rulebook implemented in Ruby. No intuition; measurable, falsifiable, automatable.

**Rulebook (theory → execution):** [pattern_detection_rulebook.md](pattern_detection_rulebook.md)  
**Chart patterns reference:** [chart_patterns_reference.md](chart_patterns_reference.md)  
**Rules checklist:** `lib/chart_patterns_rules.rb`  
**Code:** `lib/pattern_detection.rb` + `lib/pattern_detection/*.rb`

---

## Global pre-conditions (mandatory)

- **Market context filter:** 60m trend (EMA 50 vs 200), 15m volatility (ATR > median last 20 days), **index volume** (REL_VOL_15M ≥ 1.1). If volatility or volume fails → **skip options buying**.
- **Trend with volume:** BULLISH confirmed only if EMA50 > EMA200 **and** REL_VOL_15M ≥ 1.2 **and** close(15m) > VWAP(15m). BEARISH mirror. Trend without volume → ignore.
- **MTF filter:** CE only if 60m bullish; PE only if 60m bearish.
- **Options filter:** IV < 70th percentile, ATM or ATM±1, time to expiry ≥ 2 days.

---

## Index volume (spot index, not option volume)

- **VolumeMetrics** (`lib/pattern_detection/volume_metrics.rb`): INDEX_VOL, AVG_VOL = SMA(vol, 20), REL_VOL = vol/avg_vol for 1m/5m/15m. VWAP over series.
- **Master volume filter:** TRADE_ALLOWED only if REL_VOL_15M ≥ 1.1. Below average → no options buying (theta + fake moves).
- **Fake breakout filter:** Price breaks level but REL_VOL_5M < 1.0 → do NOT buy option. Saves capital.
- **Volume + VWAP:** Bullish confirmation = price > VWAP and REL_VOL_5M ≥ 1.2; bearish = price < VWAP and REL_VOL_5M ≥ 1.2. VWAP without volume = irrelevant.

Pattern-specific volume: H&S REL_VOL at HEAD ≥ 1.3, confirm REL_VOL_5M ≥ 1.5; double top/bottom volume(top2) < volume(top1), trigger vol ≥ 1.5×AVG_VOL_5M; triangles compression REL_VOL_15M < 1.0, breakout REL_VOL_5M ≥ 2.0; flags impulse REL_VOL_15M ≥ 1.8, flag vol ≤ 0.6×impulse vol, entry REL_VOL_1M ≥ 2.0; engulfing REL_VOL_5M ≥ 1.5.

---

## Pipeline flow

```
Market context (60m + 15m: trend, volatility, REL_VOL_15M ≥ 1.1, trend_confirmed with VWAP) → pass?
  → Pattern detectors (H&S, double top/bottom, triangles, flags, engulfing) — each volume-strict
  → Fake breakout filter (REL_VOL_5M ≥ 1.0)
  → MTF filter (CE/PE vs 60m trend)
  → Options filter (IV, expiry, strike)
  → Signals list
```

---

## Usage

```ruby
require_relative 'lib/pattern_detection'

result = PatternDetection::Pipeline.new(
  candles_60m: candles_60m,   # array of { open, high, low, close, volume }
  candles_15m: candles_15m,
  candles_5m:  candles_5m,
  candles_1m:  candles_1m,    # optional
  iv_percentile: 50,          # optional
  days_to_expiry: 3,
  strike_offset: 0,           # ATM±1
  support_level: 29200,       # optional, for engulfing at level
  resistance_level: 29500,
  vwap: 29350,
  fib_618: 29280
).run

# result[:context_passed]   — global filter passed (volatility + index volume)
# result[:trend_60m]        — :bullish | :bearish | :neutral
# result[:trend_confirmed]  — trend + REL_VOL_15M ≥ 1.2 + close vs VWAP
# result[:volume_ok]        — REL_VOL_15M ≥ 1.1
# result[:rel_vol_15m]      — current 15m relative volume
# result[:volume_vwap]      — { confirmed:, bias:, reason: } for price vs VWAP + REL_VOL_5M
# result[:signals]          — [ { pattern:, side: :ce|:pe, sl:, tp:, reason: }, ... ]
```

---

## Detectors (inputs → output)

| Detector | Timeframe | Output |
|----------|-----------|--------|
| **MarketContextFilter** | 60m, 15m | passed, trend_60m, volatility_ok |
| **HeadAndShoulders** | 15m structure, 5m confirm | valid, pattern, side, neckline, sl, tp |
| **DoubleTopBottom** | 15m, 5m trigger | valid, pattern, side, sl, tp, neckline |
| **Triangles** | 15m structure, 5m breakout + volume | valid, pattern, side, sl, tp, resistance/support |
| **FlagPennant** | 15m impulse, 5m flag | valid, pattern, side, sl, tp, impulse_height |
| **EngulfingAtLevel** | 5m at support/resistance/VWAP/fib | valid, pattern, side, sl, tp |
| **MTFFilter** | trend_60m | allow_ce? / allow_pe? |
| **OptionsFilter** | IV, expiry, strike | passed |

---

## Critical reality check

- Patterns without volume = trash
- Lower timeframe patterns against HTF trend = donation
- 2–3 patterns, executed perfectly > everything else

---

## Next steps (optional)

1. Map **pattern → CE/PE strike logic** (ATM, ATM±1).
2. Add **option chain + OI confirmation** layer.
3. Wire pipeline into **Delta live** or **Dhan** flow (e.g. run after AnalysisAgent, feed signals to Risk/Execution).
