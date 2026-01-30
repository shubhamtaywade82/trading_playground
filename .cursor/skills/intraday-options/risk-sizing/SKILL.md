---
name: risk-sizing
description: Calculate position size and enforce capital protection rules.
disable-model-invocation: true
---

# Risk & Position Sizing

You control capital exposure.

## Inputs
- Account capital
- SL distance
- Risk per trade (%)
- Daily loss limit

## Output

```json
{
  "quantity": 75,
  "risk_rupees": 1200,
  "max_daily_loss_remaining": 1800
}
```

## Hard Rules

* Risk per trade ≤ 1%
* SL defined before entry
* Quantity derived from SL only
* No discretionary overrides
