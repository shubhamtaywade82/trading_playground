# Trading Playground

Standalone Ruby scripts for the **PCR Trend Reversal** intraday options strategy (NIFTY / SENSEX).

## Strategy

Full rules and assumptions: [docs/pcr_trend_reversal_strategy.md](docs/pcr_trend_reversal_strategy.md).

- **Edge:** PCR (OI) sentiment reversal + 5-min price action confirmation.
- **Instruments:** Weekly expiry ATM CE/PE only.
- **Capital:** 20k INR; 5–10 trades/day; target ~5k INR/day.

## Repo layout

- `docs/` — Strategy doc and any notes.
- Scripts (to be added) — One-off or reusable Ruby scripts (screening, sizing, data checks, etc.).

## Requirements

Ruby 3.x. Scripts may use the Dhan API (or other data/order sources) as needed.
