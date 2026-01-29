# Delta Exchange (India) — Ruby integration

Delta-specific code lives under `lib/delta/` so it stays separate from DhanHQ and shared libs.

| File               | Role                                                                                   |
| ------------------ | -------------------------------------------------------------------------------------- |
| `client.rb`        | REST client for Delta v2 API: products, ticker, candles, wallet, orders, place/cancel. |
| `format_report.rb` | Console and Telegram formatting for perpetual analysis output.                         |
| `action_logger.rb` | Logs AI suggestions (bias, reason, action, levels) to `log/delta_ai_actions.jsonl`.    |

Scripts: `generate_ai_prompt_delta.rb`, `verify_delta_actions.rb`. Shared libs (e.g. `technical_indicators`, `smc`, `ai_caller`) remain in `lib/`.
