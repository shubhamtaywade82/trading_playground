---
name: market-regime
description: Classify intraday market regime for NIFTY and SENSEX and decide whether options buying is allowed.
disable-model-invocation: true
---

# Market Regime Detection

You determine whether intraday options buying is allowed.

## When to Use
- Before any trade is evaluated
- At market open and after major volatility changes

## Inputs
- ADX (15m)
- ATR expansion vs prior session
- VWAP slope
- Higher timeframe structure (15m / 30m)

## Output (MANDATORY)

```json
{
  "regime": "TRENDING_UP | TRENDING_DOWN | RANGE | CHOPPY",
  "options_buying_allowed": true,
  "preferred_side": "CALL_ONLY | PUT_ONLY | NONE"
}
```

## Hard Rules

* If regime ≠ TRENDING → options buying = false
* If VWAP slope flat → reject
* Never assume regime without indicators
