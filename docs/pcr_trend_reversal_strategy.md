# PCR Trend Reversal Strategy — Intraday Options (NIFTY / SENSEX)

## Overview

Intraday options **buying only** strategy: CE long for bullish reversals, PE long for bearish reversals. Uses **PCR (Put-Call Ratio)** changes via Open Interest (OI) for sentiment, with **price action confirmation** on the underlying index. Suited to both trending days (reversals at exhaustion) and choppy days (multiple reversals). Trade cap: **5–10 per day**.

**Goal:** ~5,000 INR net per day with 20,000 INR capital, **50% in use** (10,000 INR) for trading (3–5 high-conviction trades, up to 10 on choppy days). Target risk-reward **1:1 to 1:2**. Weekly expiry **ATM** strikes; **5-minute chart** on underlying (NIFTY spot/futures).

---

## Assumptions

| Item | Value |
|------|--------|
| NIFTY lot size | 65 (SENSEX: 20) |
| ATM premium (intraday) | 80–120 points (~5,200–7,800 INR per lot NIFTY; ~1,600–2,400 SENSEX) |
| Capital | 20,000 INR total; **50% in use** = 10,000 INR |
| Per-trade allocation | 2,000–2,500 INR from trading pool (1–2 lots max) |
| Max risk per trade | 1–2% of capital (200–400 INR) |
| Data | Live PCR (OI) every 5 min; 5-min candlestick charts |
| Session | 9:30 AM – 3:00 PM IST (avoid first 15 min) |
| Backtest win rate (dual confirmation) | ~60–70% (actual results vary) |

---

## How PCR Works Here

- **PCR** = Put OI / Call OI (all strikes). Focus on **change in OI**, not level.
- **Rising Put OI** (put writers dominant) → bullish sentiment.
- **Rising Call OI** (call writers dominant) → bearish sentiment.
- **Reversal** = dominant side flips (e.g. put writers aggressive → call writers take over).

Use PCR as a **sentiment reversal** filter; confirm with underlying price action.

---

## Entry Rules

Update PCR every 5 minutes; watch 5-min chart of underlying.

### CE Long (Bullish Reversal — Buy Call)

1. **Context:** Bearish trend in underlying (e.g. NIFTY lower lows).
2. **PCR:** Call writers were dominant → put writers add OI faster (PCR turns up).
3. **Confirmation:** Bullish candlestick at reversal (e.g. morning star, bullish engulfing, hammer at support).
4. **Entry:** Buy ATM CE after confirmation (e.g. NIFTY spot 22,500 → buy 22,500 CE).
5. **Window:** Only between 9:45 AM and 2:30 PM.

### PE Long (Bearish Reversal — Buy Put)

1. **Context:** Bullish trend in underlying (e.g. NIFTY higher highs).
2. **PCR:** Put writers were dominant → call writers add OI faster (PCR turns down).
3. **Confirmation:** Bearish candlestick at reversal (e.g. evening star, bearish engulfing, shooting star at resistance).
4. **Entry:** Buy ATM PE after confirmation (e.g. NIFTY spot 22,500 → buy 22,500 PE).

### Trade Limit and Filtering

- **Cap:** 5–10 setups per day.
- **Choppy days:** Prefer stronger confirmations (e.g. patterns at VWAP, prior high/low).
- **Skip:** No clear reversal, or PCR flat around 1 (range-bound).

---

## Exit Rules (Underlying-Based)

| Type | Rule |
|------|------|
| **Profit target** | Start 1:1 (SL 25 pts on underlying → target 25–50 pts). Extend to 1:2 in strong trends. Options: 20–50 pt premium gain (~1,300–3,250 INR per lot NIFTY; ~400–1,000 SENSEX). Trail after ~20 pt gain (move SL to breakeven). |
| **Stop loss** | Extreme of confirming candle: **CE** = low of pattern, **PE** = high of pattern. Max SL: 20–30 pts on underlying (premium loss ~10–20 pts; ~650–1,300 INR per lot NIFTY, ~200–400 SENSEX). |
| **Time** | Close all by 3:00 PM; or exit if no move in 30–45 min after entry. |
| **Reversal** | Exit if PCR flips against position or counter candlestick pattern appears. |

**Example (PE long):** NIFTY 22,500 → buy 22,500 PE @ 100. SL 22,530 (30 pts). Target 22,450 (50 pts); premium ~150 → 50×65 = 3,250 INR per lot. 1–2 lots. Repeat 2–4 such trades for 5k daily target.

---

## Capital and Position Sizing

- **Total:** 20,000 INR; **50% in use** = 10,000 INR for trading (rest as reserve).
- **Per trade:** From 10k pool, allocate 2,000–2,500 INR per trade; risk 200–400 INR (1–2% of total capital). 1–2 lots (e.g. NIFTY premium 100 → 1 lot 6,500 INR; SENSEX 100 → 1 lot 2,000 INR).
- **Scaling:** 2 lots after wins; 1 lot after losses.
- **5k profit:** 4–5 trades averaging 1,000–1,250 INR each (net of 1–2 losses). Choppy: more small wins; trending: fewer, larger.

---

## Implementation Notes

- **SENSEX:** Same PCR logic (BSE data); lower options liquidity — prefer ATM, smaller size.
- **Tools:** Broker OI/PCR; 20-period EMA on 5-min for trend bias (enter in direction of bias).
- **Risk:** Theta minimal intraday; prefer high-volume days. Track 20–30 days to tune.
- **Timeframes:** Chart and session recommendations: [Timeframes for intraday options](timeframes_intraday_options.md) (5-min vs 15-min, prime window 10:15–2:30, exit by 3:00 PM).

---

## Summary Checklist (Per Trade)

- [ ] PCR reversal aligned with direction (CE ↑ put OI, PE ↑ call OI).
- [ ] Candlestick confirmation on 5-min underlying.
- [ ] Entry in window 9:45–2:30.
- [ ] SL at pattern extreme; max 20–30 pts underlying.
- [ ] Target 1:1 or 1:2; trail after ~20 pt gain.
- [ ] Daily count within 5–10 trades.
