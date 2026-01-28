# Trading Playground

Standalone Ruby scripts for the **PCR Trend Reversal** intraday options strategy (NIFTY / SENSEX).

## Strategy

Full rules and assumptions: [docs/pcr_trend_reversal_strategy.md](docs/pcr_trend_reversal_strategy.md). Chart and session timeframes: [docs/timeframes_intraday_options.md](docs/timeframes_intraday_options.md).

- **Edge:** PCR (OI) sentiment reversal + 5-min price action confirmation.
- **Instruments:** Weekly expiry ATM CE/PE only.
- **Capital:** 20k INR; 5–10 trades/day; target ~5k INR/day.
- **Session:** Prime window 10:15–2:30; square off by 3:00 PM.

## Repo layout

- `docs/` — Strategy doc and any notes.
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

**Mock (no Dhan):** `MOCK_DATA=1 ruby generate_ai_prompt.rb` — uses fake market data (no credentials); prompt + AI still run. Use to test AI integration without live data.

**Underlyings:** By default both NIFTY and SENSEX are analyzed per cycle. Override: `UNDERLYINGS=NIFTY,SENSEX` or `UNDERLYING=NIFTY` for a single index.

## Requirements

Ruby 3.x. Scripts use the DhanHQ gem for market data.
