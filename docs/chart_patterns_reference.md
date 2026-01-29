# Chart Patterns Reference (Practitioner-Grade)

Clean, complete list of effective chart patterns with **how to identify them in real charts** (rules, confirmations, traps). Consolidated from Groww, IG, and NSE Academy (Technical Pattern module). How traders and algos actually detect them.

---

## 1. Reversal Chart Patterns (Trend Change)

Indicate **trend exhaustion + reversal probability**.

### 1.1 Head and Shoulders (H&S)

**Structure**

- **Left Shoulder**: Higher high → pullback
- **Head**: Higher high than LS → pullback
- **Right Shoulder**: Lower high than Head
- **Neckline**: Connects swing lows

**Identification rules**

- Prior **uptrend mandatory**
- Right shoulder must fail to break head high
- **Neckline break + close** = confirmation
- Volume: high on LS, higher on Head, weak on RS

**Target**

```
Target = Neckline – (Head – Neckline)
```

🔁 **Inverse H&S** = bullish version (downtrend → uptrend).

---

### 1.2 Double Top / Double Bottom

**Structure**

- Two rejection points at **same price zone**
- Middle retracement of at least **30–50%**

**Identification rules**

- Clear prior trend
- Second top/bottom must show **weaker momentum**
- Confirmation only after **neckline break**

**Target**

```
Target = Height of pattern projected from neckline
```

---

### 1.3 Triple Top / Triple Bottom

- Same logic as double, but three failed attempts
- Stronger pattern, slower formation
- More reliable on **higher timeframes**

---

### 1.4 Rounding Top / Rounding Bottom

**Structure**

- Gradual loss of momentum
- Price forms a **curve**, not sharp swings

**Identification rules**

- Volume dries up near the curve’s apex
- Break of support/resistance confirms reversal

⚠️ Harder to code → usually **visual + volume-based detection**.

---

## 2. Continuation Patterns (Trend Pause → Resume)

Indicate **trend consolidation**, not reversal.

### 2.1 Flags

**Structure**

- Strong impulsive move (flagpole)
- Small rectangular consolidation against trend

**Identification rules**

- Flag slope is **against the trend**
- Volume: high on pole, low during flag
- Breakout in trend direction = entry

**Target**

```
Target ≈ Flagpole height
```

---

### 2.2 Pennants

**Structure**

- Similar to flag but consolidation is **triangular**
- Lower highs + higher lows

**Identification rules**

- Short duration
- Breakout must be **high volume**

---

### 2.3 Rectangles (Range Breakout)

**Structure**

- Horizontal support and resistance
- Price oscillates multiple times

**Identification rules**

- At least **2 touches** on both boundaries
- Volume contraction inside range
- Expansion on breakout

---

## 3. Triangle Patterns (Compression → Expansion)

Important for **options buying** (volatility expansion).

### 3.1 Ascending Triangle (Bullish)

**Structure**

- Flat resistance
- Rising support

**Identification rules**

- Buyers more aggressive (higher lows)
- Break above resistance with volume

---

### 3.2 Descending Triangle (Bearish)

**Structure**

- Flat support
- Falling resistance

**Identification rules**

- Sellers more aggressive
- Breakdown below support

---

### 3.3 Symmetrical Triangle (Neutral → Directional)

**Structure**

- Lower highs + higher lows
- Price compression

**Identification rules**

- Direction decided by **breakout**
- Avoid predicting direction before break

---

## 4. Candlestick Patterns (Micro Price Action)

Best used at: support/resistance, VWAP, trendline, Fibonacci levels (Groww + NSE emphasis).

### 4.1 Single-Candle

| Pattern | Rule | Context |
|--------|------|--------|
| **Doji** | Open ≈ Close | Indecision; needs confirmation candle |
| **Hammer** | Small body, long lower wick | At support → bullish |
| **Hanging Man** | Small body, long lower wick | At top → bearish |

---

### 4.2 Two-Candle

| Pattern | Rule |
|--------|------|
| **Bullish Engulfing** | Second candle fully engulfs first; after decline |
| **Bearish Engulfing** | Opposite; after rally |

---

### 4.3 Three-Candle

| Pattern | Rule |
|--------|------|
| **Morning Star** | Bearish → small indecision → strong bullish |
| **Evening Star** | Bullish → indecision → strong bearish |

---

## 5. Advanced / Structural Patterns

(NSE technical pattern syllabus.)

### 5.1 Fibonacci Retracement

**Key levels:** 38.2%, 50%, 61.8%

**Identification rules**

- Draw from **swing low → swing high**
- Look for: price reaction, volume confirmation, candle rejection

⚠️ Fib is **confluence tool**, not standalone.

---

### 5.2 Elliott Wave (Advanced)

**Structure:** 5-wave impulse, 3-wave correction (ABC)

**Rules (non-negotiable)**

- Wave 3 is never shortest
- Wave 4 doesn’t overlap Wave 1
- Requires higher timeframe context

⚠️ Difficult to automate reliably.

---

## 6. Volume-Confirmed Patterns (Critical for Options)

From NSE **Price Action + Volume** module.

**Valid pattern MUST show:**

- Volume expansion on breakout
- Volume divergence near reversals
- Weak volume = false breakout risk

---

## 7. What Actually Works Best (Reality Check)

For **options buying + algo trading**, prioritize:

| Tier | Patterns |
|------|----------|
| **Tier-1** (high reliability, algo-friendly) | Head & Shoulders / Inverse, Double Top/Bottom, Triangles, Flags & Pennants, Engulfing candles (with levels) |
| **Tier-2** (contextual) | Rectangles, Fibonacci confluence, Morning/Evening Star |
| **Tier-3** (manual / discretionary) | Elliott Wave, Rounding patterns |

---

## 8. Algo-Friendly Identification Summary (Rules Engine)

Every pattern detection boils down to:

1. **Swing high / swing low** detection
2. **Trend validation**
3. **Geometry rules** (higher highs, equal tops, compression)
4. **Volume confirmation**
5. **Breakout candle close**

**If any of these are missing → pattern is invalid.**

---

## Reuse in This Project

- **Reference:** `docs/chart_patterns_reference.md` (this file)
- **Rules checklist:** `lib/chart_patterns_rules.rb` (constants for algo steps and tiers)
- **Existing SMC:** `lib/smc.rb` (swing highs/lows, FVG, structure) — align pattern logic with this doc.

Next steps (optional): strict algo rules (pseudo-code), pattern detector module, pattern → strike selection → SL/TP mapping.
