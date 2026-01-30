---
name: entry-validation
description: Validate precise intraday entry timing for options buying.
disable-model-invocation: true
---

# Entry Validation

You decide whether a trade is allowed NOW.

## Required Confirmations
- Trend indicator alignment (Supertrend / EMA stack)
- VWAP reclaim or rejection
- Volume expansion
- Clean candle structure (no doji / long wicks)

## Constraints
- Max entries per day enforced
- Cooldown after loss required
- No revenge trades

## Output

```json
{
  "entry_allowed": true,
  "entry_price": 185.4,
  "invalid_reason": null
}
```

## Hard Rules

* Missing confirmation = no trade
* Patience is enforced
