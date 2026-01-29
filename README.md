# Trading Playground

Standalone Ruby scripts for the **PCR Trend Reversal** intraday options strategy (NIFTY / SENSEX).

## Strategy

Full rules and assumptions: [docs/pcr_trend_reversal_strategy.md](docs/pcr_trend_reversal_strategy.md). Chart and session timeframes: [docs/timeframes_intraday_options.md](docs/timeframes_intraday_options.md). Practitioner chart patterns: [docs/chart_patterns_reference.md](docs/chart_patterns_reference.md). **Rulebook (theory → execution):** [docs/pattern_detection_rulebook.md](docs/pattern_detection_rulebook.md). Executable pattern detection + index volume: [docs/pattern_detection_algo.md](docs/pattern_detection_algo.md) and `lib/pattern_detection.rb`. **Options-buying pattern engine** (data → analysis → decision → execution): [docs/pattern_engine_integration.md](docs/pattern_engine_integration.md), `run_pattern_engine.rb`, and `lib/indicators/`, `lib/market_context/`, `lib/patterns/`, `lib/options/`, `lib/engine/`.

- **Edge:** PCR (OI) sentiment reversal + 5-min price action confirmation.
- **Instruments:** Weekly expiry ATM CE/PE only.
- **Capital:** 20k INR; 5–10 trades/day; target ~5k INR/day.
- **Session:** Prime window 10:15–2:30; square off by 3:00 PM.

## Repo layout

- `docs/` — Strategy doc, chart patterns reference, and notes.
- `lib/` — Shared helpers (e.g. `technical_indicators.rb`).
- `generate_ai_prompt.rb` — Fetches live NIFTY data (PCR, OHLC, 5-min intraday, SMA, RSI) and prints an AI prompt for CE/PE reversal suggestions.

## Running `generate_ai_prompt.rb`

1. **Install:** `bundle install` (DhanHQ, openai, ollama-client).
2. **Env:** Copy `.env.example` to `.env` and fill in values. Required: `DHAN_CLIENT_ID`, `DHAN_ACCESS_TOKEN`.
3. **Run:** `ruby generate_ai_prompt.rb` (during market hours).
4. **Prompt only:** Script always prints the filled prompt. Copy it into any AI if you prefer.

**Optional – get AI analysis in the same run:**

- **OpenAI:** `AI_PROVIDER=openai OPENAI_API_KEY=sk-... ruby generate_ai_prompt.rb`
  Optional: `OPENAI_MODEL=gpt-4o` (default), `AI_MODEL=gpt-4o-mini`, etc.
- **Ollama (local):** `AI_PROVIDER=ollama ruby generate_ai_prompt.rb` — uses [ollama-client](https://github.com/shubhamtaywade82/ollama-client) gem (`/api/generate`, plain text). Optional: `OLLAMA_HOST`, `OLLAMA_MODEL`, `OLLAMA_TIMEOUT`.

**Optional – run every 5 minutes (loop):**

- `LOOP_INTERVAL=300 ruby generate_ai_prompt.rb` — runs a cycle, sleeps 300 seconds, repeats. Errors in a cycle are logged and the loop continues.

**Telegram:** Set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` (same as algo_trading_api) to send each symbol’s prompt + AI analysis as Telegram messages (chunked if needed).

**Mock (no Dhan):** `MOCK_DATA=1 ruby generate_ai_prompt.rb` — uses fake market data (no credentials); prompt + AI still run. Use to test AI integration without live data.

**Underlyings:** By default both NIFTY and SENSEX are analyzed per cycle. Override: `UNDERLYINGS=NIFTY,SENSEX` or `UNDERLYING=NIFTY` for a single index.

## Delta Exchange (crypto derivatives)

[Delta Exchange](https://docs.delta.exchange) is supported for crypto perpetuals (BTC, ETH, etc.) with **market data**, **AI analysis**, and **trading**.

**AI analysis (same flow as NIFTY):**
`ruby generate_ai_prompt_delta.rb` — fetches Delta ticker + 5m candles for BTCUSD/ETHUSD (or `DELTA_SYMBOLS`), computes SMA/RSI/trend, builds a prompt, and calls OpenAI/Ollama. Optional: `AI_PROVIDER=ollama`, `LOOP_INTERVAL=300`, `TELEGRAM_CHAT_ID`. No Delta credentials needed for market data.

**Trading (place/cancel orders):**
Set `DELTA_API_KEY` and `DELTA_API_SECRET` in `.env`. Use the Ruby client:

```ruby
require_relative 'lib/delta/client'
client = DeltaExchangeClient.new
# Public (no auth)
client.ticker('BTCUSD')
client.candles(symbol: 'BTCUSD', resolution: '5m', start_ts: Time.now.to_i - 3600, end_ts: Time.now.to_i)
# Auth: wallet, orders, place_order, cancel_order
client.wallet_balances
client.orders(states: 'open')
client.place_order(product_symbol: 'BTCUSD', size: 1, side: 'buy', order_type: 'limit_order', limit_price: '85000')
client.cancel_order(id: 12345, product_id: 27)
```

**Action logging and verification:**
Each AI suggestion is appended to `log/delta_ai_actions.jsonl` (timestamp, symbol, market snapshot, bias, reason, action, and extracted price levels). Disable with `DELTA_LOG_ACTIONS=0`. To check whether suggested levels were hit by current price:

```bash
ruby verify_delta_actions.rb --last 20
ruby verify_delta_actions.rb --since 2026-01-29
ruby verify_delta_actions.rb --hours 24 --no-fetch   # print log only, no API call
```

**Python:** `pip install delta-rest-client` (see `requirements.txt`). Run `python3 delta_example.py`.

## Requirements

Ruby 3.x. Scripts use the DhanHQ gem for market data. Delta: Ruby `rest-client` gem, or Python `delta-rest-client` (optional).
