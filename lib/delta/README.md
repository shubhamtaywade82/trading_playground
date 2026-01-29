# Delta Exchange (India) — Ruby integration

Delta-specific code lives under `lib/delta/` so it stays separate from DhanHQ and shared libs.

| File               | Role                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------ |
| `client.rb`        | REST client: products, ticker, candles, orderbook, wallet, orders, place/cancel.           |
| `analysis.rb`      | Institutional analysis: key levels (SMC), funding regime, ATR context, orderbook, HTF.     |
| `format_report.rb` | Console and Telegram: market, key levels, LT/HTF, funding, volatility (ATR), SMC, verdict. |
| `action_logger.rb` | Logs AI suggestions to `log/delta_ai_actions.jsonl`.                                       |

Flow: 5m + 1h candles and orderbook → key levels, ATR(14), HTF trend/structure, funding regime → structured prompt and report. Scripts: `generate_ai_prompt_delta.rb`, `verify_delta_actions.rb`. Shared libs in `lib/`.
