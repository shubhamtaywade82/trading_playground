# Intraday Options (NIFTY & SENSEX) — Skill Pack

Risk-gated trading engine. Each skill is atomic; chain in order. **If any skill rejects, the trade is dead.**

## Skill chain (order is mandatory)

1. **market-regime** — Classify regime; allow options buying only when TRENDING
2. **strike-selection** — ATM ±1%, IV Rank &lt; 60, liquidity OK
3. **entry-validation** — Confirm trend, VWAP, volume, candle structure; enforce max entries & cooldown
4. **risk-sizing** — Position size from SL; risk ≤ 1%, daily limit
5. **execution-safety** — No duplicates; SL confirmed; handle slippage/partial fills
6. **exit-management** — Hard SL, breakeven, trail, time/vol exit
7. **post-trade-intel** — Expectancy, kill switches (3 losses, daily limit, slippage, vol anomaly)

## Usage

Do **not** auto-fire all skills. Run in sequence; each must approve before the next.

- `/market-regime` → if `options_buying_allowed: false` → stop
- `/strike-selection` → if no valid strike → stop
- `/entry-validation` → if `entry_allowed: false` → stop
- `/risk-sizing` → compute quantity and risk
- `/execution-safety` → place order; confirm SL
- `/exit-management` → manage open trade
- `/post-trade-intel` → after exit; may set `trading_allowed: false`

## Verdict

This is a **risk-gated trading engine**, not a strategy. Wire into Cursor, Rails + DhanHQ, or OpenWebUI with the same chain and guardrails.
