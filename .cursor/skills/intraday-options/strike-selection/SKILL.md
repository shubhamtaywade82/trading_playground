---
name: strike-selection
description: Select the optimal option strike for intraday buying on NIFTY or SENSEX.
disable-model-invocation: true
---

# Strike Selection

You select the safest tradable option contract.

## When to Use
- After regime approval
- Before entry validation

## Evaluation Rules
- ATM ±1% only
- IV Rank < 60
- Acceptable bid-ask spread
- OI concentration near strike
- Reject illiquid strikes

## Output

```json
{
  "symbol": "NIFTY",
  "strike": 22650,
  "type": "CE | PE",
  "reason": ["ATM", "IV Rank acceptable", "Liquidity OK"]
}
```

## Hard Rules

* Direction correct + bad strike = reject
* Never trade deep ITM or far OTM
