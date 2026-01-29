# Delta Exchange (India) — Ruby integration

Delta-specific code lives under `lib/delta/` so it stays separate from DhanHQ and shared libs.

## Core

| File               | Role                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------ |
| `client.rb`        | REST client: products, ticker, candles, orderbook, wallet, orders, place/cancel.           |
| `analysis.rb`      | Institutional analysis: key levels (SMC), funding regime, ATR context, orderbook, HTF.     |
| `format_report.rb` | Console and Telegram: market, key levels, LT/HTF, funding, volatility (ATR), SMC, verdict. |
| `action_logger.rb` | Logs AI suggestions to `log/delta_ai_actions.jsonl`.                                       |

## Sub-agents (professional trader pipeline)

| File / Dir        | Role                                                                                       |
| ----------------- | ------------------------------------------------------------------------------------------ |
| `agents.rb`       | Loader for all agents.                                                                     |
| `agents/`         | Sub-agents: MarketData → Analysis → Thinking → Risk → Execution.                            |
| `agents/market_data_agent.rb`  | Fetches ticker, 5m + 1h candles, orderbook for one symbol.                          |
| `agents/analysis_agent.rb`    | Enriches with SMC, RSI, SMA, ATR, HTF trend, funding, orderbook imbalance (no AI). |
| `agents/thinking_agent.rb`    | Builds professional-trader prompt, calls Ollama/OpenAI, parses Bias/Reason/Action/Conviction. |
| `agents/risk_agent.rb`        | Suggests size fraction, stop-loss, take-profit from ATR and key levels; optional Ollama sizing. |
| `agents/execution_agent.rb`   | Places/cancels orders only when `LIVE_TRADING=1` and Delta API is authenticated; logs intent and result. |
| `orchestrator.rb` | Runs pipeline for configured symbols; dry-run by default.                                  |

Flow: **MarketData** → **Analysis** (SMC, indicators, HTF) → **Thinking** (Ollama verdict) → **Risk** (size, SL, TP) → **Execution** (optional live orders). Scripts: `run_delta_live.rb` (recommended), `generate_ai_prompt_delta.rb`, `verify_delta_actions.rb`. Shared libs in `lib/`.

## Env: dry-run vs live

**Dry-run (no orders, only analysis + AI verdict):**

In `.env` (or leave unset):

```env
LIVE_TRADING=0
```

Or omit `LIVE_TRADING`. You’ll see: `Execution: skipped — LIVE_TRADING not set`.

**Live trading (real orders):**

In `.env`:

```env
LIVE_TRADING=1
DELTA_MAX_POSITION_USD=500
DELTA_API_KEY=your_api_key
DELTA_API_SECRET=your_api_secret
```

- `DELTA_MAX_POSITION_USD` = max notional per trade (USD). Required for sizing; without it you get `Execution: skipped — Set DELTA_MAX_POSITION_USD for live sizing` or `Size zero or negative`.
- Get API key/secret from [Delta Exchange](https://www.delta.exchange) (API section).
