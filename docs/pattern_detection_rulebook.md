# Pattern Detection Rulebook — Theory to Execution

We stop discussing theory here. Everything below is **executable trading logic**.

This is a **strict, algo-ready rulebook**, purpose-built for **options buying**, operating on **1m / 5m / 15m / 60m OHLCV data**.

There is:

- ❌ No discretion  
- ❌ No “looks like”  
- ❌ No subjective interpretation  

Every rule is **measurable, testable, and automatable**.

**Implementation:** `lib/pattern_detection.rb` + `lib/pattern_detection/*.rb`  
**Usage & volume rules:** [pattern_detection_algo.md](pattern_detection_algo.md)

---

## GLOBAL PRE-CONDITIONS (MANDATORY)

These conditions apply to **all patterns**. If **any** fail → **NO TRADE**.

### Data Model

```pseudo
candles[tf] = OHLCV array where tf ∈ {1m, 5m, 15m, 60m}
```

### Core Functions

```pseudo
swing_high(index, timeframe)
swing_low(index, timeframe)
ATR(timeframe, period)
EMA(timeframe, period)
RSI(timeframe, period)
AVG_VOLUME(timeframe, period)
```

---

## Market Context Filter (60m + 15m)

### Trend Definition (60m)

```pseudo
bullish = EMA(60m, 50) > EMA(60m, 200)
bearish = EMA(60m, 50) < EMA(60m, 200)
```

### Volatility Filter (15m)

```pseudo
valid_volatility =
  ATR(15m,14) > median(ATR(15m,14) over last 20 days)
```

If volatility filter fails → **skip options buying** (reason: theta decay dominates low-volatility regimes).

---

## 1️⃣ HEAD & SHOULDERS / INVERSE H&S (REVERSAL)

### Timeframes

- Structure: **15m**
- Confirmation: **5m**
- Entry refinement: **1m**

### Detection Logic (Bearish H&S)

```pseudo
swings = detect_swings(15m)

LS   = swing_high at index i
HEAD = swing_high at index j where j > i AND HEAD.price > LS.price
RS   = swing_high at index k where k > j AND RS.price < HEAD.price

NECKLINE =
  line between:
    swing_low between LS & HEAD
    swing_low between HEAD & RS
```

### Validation Rules

```pseudo
valid_pattern if:
  abs(LS.price - RS.price) / HEAD.price < 0.03
  volume(HEAD) > volume(RS)
  prior_trend == bullish (from 60m)
```

### Confirmation

```pseudo
confirm if:
  5m close < neckline value
  AND volume(5m) > AVG_VOLUME(5m, 20)
```

### Trade Execution

```pseudo
BUY ATM or ATM-1 PE
```

### Risk Management

```pseudo
SL = RS.high OR (entry_price - 0.6 * ATR(5m))
TP = entry_price + (HEAD.price - neckline.price)
```

---

## 2️⃣ DOUBLE TOP / DOUBLE BOTTOM

### Timeframes

- Structure: **15m**
- Trigger: **5m**

### Detection (Double Top)

```pseudo
TOP1 = swing_high at i
TOP2 = swing_high at j where j > i

swing_low_between = minimum low between i and j
```

### Validation

```pseudo
valid if:
  abs(TOP1.price - TOP2.price) / TOP1.price < 0.02
  RSI(15m at TOP2) < RSI(15m at TOP1)
```

### Confirmation

```pseudo
5m close < swing_low_between
```

### Trade

```pseudo
BUY PE
SL = TOP2.high
TP = swing_low_between - (TOP1.price - swing_low_between)
```

---

## 3️⃣ TRIANGLES (VOLATILITY EXPANSION — OPTIONS EDGE)

### Timeframes

- Structure: **15m**
- Breakout: **5m**

### Ascending Triangle (Bullish)

```pseudo
RESISTANCE = ≥2 equal highs
SUPPORT    = ≥2 higher lows
```

### Validation

```pseudo
slope(SUPPORT) > 0
volume contracts during formation
```

### Breakout Confirmation

```pseudo
5m close > RESISTANCE
AND volume(5m) > 1.5 * AVG_VOLUME(5m, 20)
```

### Trade

```pseudo
BUY CE
SL = last higher low
TP = RESISTANCE + triangle height
```

### Descending Triangle → PE

(Inverted logic)

---

## 4️⃣ FLAGS & PENNANTS (TREND CONTINUATION)

### Timeframes

- Impulse: **15m**
- Consolidation: **5m**
- Entry: **1m**

### Detection

```pseudo
IMPULSE:
  price_move > 2 * ATR(15m)
  AND volume spike

FLAG:
  channel slope opposite impulse
  duration < 10 candles
  volume < impulse volume
```

### Breakout

```pseudo
1m close breaks flag channel
```

### Trade

```pseudo
BUY in impulse direction
SL = flag extreme
TP = impulse height
```

---

## 5️⃣ ENGULFING CANDLES (PRECISION ONLY)

⚠️ **Never traded standalone** — used only at predefined levels.

### Detection (Bullish Engulfing)

```pseudo
C1 = bearish candle
C2 = bullish candle

valid if:
  C2.open < C1.close
  C2.close > C1.open
  occurs at support / VWAP / Fib 61.8
  RSI(5m) < 35
```

### Trade

```pseudo
BUY CE
SL = C2.low
TP = nearest resistance
```

---

## 6️⃣ FIBONACCI (CONFLUENCE TOOL)

```pseudo
SWING = last impulse on 15m
FIB_LEVELS = {38.2, 50, 61.8}
```

### Valid Only If

```pseudo
price reacts at fib level
AND bullish candle forms
AND (RSI divergence OR volume spike)
```

⚠️ Trade only when **another pattern confirms**.

---

## 7️⃣ MULTI-TIMEFRAME ALIGNMENT (NON-NEGOTIABLE)

```pseudo
If trading CE:
  60m trend must be bullish
  15m structure bullish or neutral

If trading PE:
  60m trend must be bearish
```

Mismatch → **skip trade**.

---

## 8️⃣ OPTIONS-SPECIFIC FILTERS

```pseudo
IV < 70th percentile
strike ∈ {ATM, ATM±1}
time_to_expiry ≥ 2 days
```

No exceptions.

---

## FINAL EXECUTION PIPELINE

```pseudo
On every 5m close:
  update indicators
  detect 15m patterns
  validate 60m trend
  confirm breakout
  refine entry on 1m
  place order
  attach SL & TP
  monitor position independently
```

---

## HARD REALITY CHECK

- ❌ Patterns without volume = noise  
- ❌ LTF patterns against HTF trend = capital donation  
- ❌ Trading too many patterns = overfitting  
- ✅ 2–3 patterns, executed perfectly, beats everything else  

---

## Next Step

Choose one:

1. Convert this into **Rails service architecture**  
2. Implement **pattern detectors in Ruby** *(done: `lib/pattern_detection/`)*  
3. Map **pattern → CE/PE → strike selection**  
4. Add **option chain + OI confirmation**  

Say the word.
