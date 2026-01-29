# Live Trading Usage — Dhan (Options) & Delta (Crypto)

How to best use this repo for **live trading** on Dhan (NIFTY/SENSEX options buying) and Delta (crypto perpetuals). What is automated today vs decision-support only.

---

## Dhan — Options Buying (NIFTY / SENSEX)

**Current support:** **Analysis and signals only.** No order placement from this repo.

| Use | Script | What it does |
|-----|--------|---------------|
| **AI + SMC + PCR** | `ruby generate_ai_prompt.rb` | Fetches option chain, 5m OHLC, PCR, SMA, RSI, SMC (structure + FVG), key levels; AI returns CE / PE / No trade + reason + action. |
| **Chart patterns** | `ruby run_pattern_engine.rb` (with `CANDLE_SOURCE=dhan`) | Pattern engine (engulfing, H&S, double top/bottom, triangle, flag) → direction + SL/TP. No AI, no orders. |

**Best use for live options buying on Dhan:**

1. **During market hours** run:
   ```bash
   AI_PROVIDER=ollama ruby generate_ai_prompt.rb
   ```
   (or `LOOP_INTERVAL=300` for every 5 minutes).

2. Use the **Verdict** (CE / PE / No trade) and **Key levels / SMC** as **decision support**. Place **options orders manually** on the Dhan app or web (ATM/weekly CE or PE as per AI + your risk).

3. **Optional:** Run the pattern engine with Dhan candles for another signal (direction + SL/TP):
   ```bash
   CANDLE_SOURCE=dhan PATTERN_SECURITY_ID=13 PATTERN_EXCHANGE_SEGMENT=IDX_I PATTERN_INSTRUMENT=INDEX ruby run_pattern_engine.rb
   ```
   Use pattern direction/SL/TP to align or filter the AI bias.

4. **Telegram:** Set `TELEGRAM_CHAT_ID` and `TELEGRAM_BOT_TOKEN` to get Dhan analysis + verdict on your phone.

**Not in repo:** Dhan order API (place/cancel) is not wired. `PatternSignal#execute` is a placeholder. To automate options orders you’d need to add a Dhan execution layer (e.g. using the DhanHQ gem’s order APIs).

---

## Delta — Crypto Perpetuals (Futures)

**Current support:** **Full pipeline:** market data → analysis → AI → risk → **optional live execution** (perpetual futures only).

| Use | Script | What it does |
|-----|--------|---------------|
| **AI + SMC only** | `ruby generate_ai_prompt_delta.rb` | Ticker, 5m/1h candles, funding, OI, orderbook, SMC, key levels → AI Long / Short / No trade. No orders. |
| **Full pipeline + execution** | `ruby run_delta_live.rb` | Market data → Analysis → Thinking (Ollama) → Risk (size, SL, TP) → **Execution** (place order when `LIVE_TRADING=1`). |

**Best use for live crypto perpetuals on Delta:**

1. **Dry-run (no orders):**
   ```bash
   ruby run_delta_live.rb
   ```
   See AI verdict, conviction, risk (size_fraction, SL, TP). Execution is skipped.

2. **Live trading (place orders):**
   - In `.env`: `LIVE_TRADING=1`, `DELTA_API_KEY=...`, `DELTA_API_SECRET=...`, `DELTA_MAX_POSITION_USD=500` (or your cap).
   - Run:
     ```bash
     ruby run_delta_live.rb
     ```
   When AI says Long/Short, the execution agent places a **limit order** on the perpetual (product_symbol e.g. BTCUSD, ETHUSD). Size is derived from `DELTA_MAX_POSITION_USD` and risk `size_fraction`.

3. **Symbols:** `DELTA_SYMBOLS=BTCUSD,ETHUSD` (default). Add more perpetual symbols as needed.

4. **Logs:** `log/delta_ai_actions.jsonl`, `log/delta_execution_intent.jsonl`, `log/delta_execution_result.jsonl`. Use `ruby verify_delta_actions.rb` to compare suggested levels with price.

**Delta options:** This repo’s execution is **perpetual futures only** (buy/sell with size and limit_price). Delta Exchange may offer options; options order placement (strike, expiry, option type) is not implemented here.

---

## Quick Reference

| Platform | Product | Repo role | Orders |
|----------|---------|-----------|--------|
| **Dhan** | NIFTY/SENSEX options (CE/PE) | Analysis + AI + SMC + (optional) pattern engine | Manual only |
| **Delta** | Crypto perpetuals (BTCUSD, ETHUSD, …) | Full pipeline + optional execution | Automated when `LIVE_TRADING=1` |
| **Delta** | Crypto options | Not implemented | — |

---

## Env summary

**Dhan (analysis only):**  
`DHAN_CLIENT_ID`, `DHAN_ACCESS_TOKEN`, optional `AI_PROVIDER`, `UNDERLYINGS`, `TELEGRAM_*`.

**Delta (analysis):**  
No auth needed for market data. `AI_PROVIDER`, `DELTA_SYMBOLS`, optional `TELEGRAM_*`.

**Delta (live execution):**  
`LIVE_TRADING=1`, `DELTA_API_KEY`, `DELTA_API_SECRET`, `DELTA_MAX_POSITION_USD`.
