# Option Chain Data Usage (Dhan)

**Focus:** Options **buying** only — buy CE when bullish, buy PE when bearish. No option selling.

The Dhan **Option Chain** API (`POST /optionchain`) returns, per strike: CE/PE data including OI, greeks, volume, bid/ask, last price, and implied volatility. This doc describes what we use from that response in `generate_ai_prompt.rb`.

## Used in analysis

| Source | Field | Use |
|--------|--------|-----|
| `data.last_price` | Spot (underlying) LTP | Spot price when no other source; PCR context. |
| `data.oc` (per strike) | `ce.oi` / `pe.oi` | Summed → **Call OI** and **Put OI** → **PCR** (put/call ratio). |
| ATM strike | `ce.implied_volatility` | **ATM IV (CE)** — volatility context for calls. |
| ATM strike | `pe.implied_volatility` | **ATM IV (PE)** — volatility context for puts. |
| All strikes | `ce.volume` + `pe.volume` | Summed → **Total option volume** (activity gauge). |

- **PCR** is computed as Put OI / Call OI and fed into the AI prompt and console/Telegram report.
- **ATM** is the strike whose value is closest to current spot; we use that strike’s CE/PE IV and OI/volume are already aggregated.
- **ATM IV** and **total volume** are included in the AI prompt and in the Dhan format report (Market section).

## Not used yet

- **Greeks** (delta, theta, gamma, vega)
- **Top bid/ask** (top_bid_price, top_ask_price, quantities)
- **Previous** (previous_close_price, previous_oi, previous_volume)

These are available in the API response and can be wired in later if needed.

## Expiry

We call the **Expiry List** API (`POST /optionchain/expirylist`) to get active expiries, then use the **nearest expiry** (first date ≥ today) for the option chain request. Only one expiry’s chain is fetched per run.

## Rate limit

Option Chain may be called at most once every 3 seconds per Dhan docs.
