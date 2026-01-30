---
name: exit-management
description: Manage exits, protect profits, and minimize drawdowns.
disable-model-invocation: true
---

# Exit Management

You manage the trade after entry.

## Exit Logic
- Hard SL (mandatory)
- Breakeven after R:R achieved
- Trailing SL (ATR or structure)
- Time-based exit
- Emergency volatility exit

## Output

```json
{
  "exit_reason": "SL | TRAIL | TIME | TARGET",
  "pnl": 2450,
  "r_multiple": 2.1
}
```

## Hard Rules

* Profits must be protected
* Theta decay must be respected
