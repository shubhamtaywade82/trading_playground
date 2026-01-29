#!/usr/bin/env python3
"""
Minimal example using delta-rest-client (pip install delta-rest-client).
Set DELTA_API_KEY, DELTA_API_SECRET, DELTA_BASE_URL in .env or env.
Docs: https://docs.delta.exchange
"""
import os

try:
    from delta_rest_client import DeltaRestClient
except ImportError:
    print("Install: pip install delta-rest-client")
    raise

BASE_URL = os.environ.get("DELTA_BASE_URL", "https://api.india.delta.exchange")
API_KEY = os.environ.get("DELTA_API_KEY", "")
API_SECRET = os.environ.get("DELTA_API_SECRET", "")


def main():
    client = DeltaRestClient(base_url=BASE_URL, api_key=API_KEY, api_secret=API_SECRET)
    # Public: get ticker (no auth) — client returns result dict directly
    ticker = client.get_ticker("BTCUSD")
    r = ticker.get("result", ticker) if isinstance(ticker, dict) else ticker
    if isinstance(r, dict) and (r.get("symbol") or r.get("mark_price") is not None):
        print(f"{r.get('symbol', 'BTCUSD')} mark_price={r.get('mark_price')} spot_price={r.get('spot_price')}")
    else:
        print(ticker)
    # Auth: wallet (requires API key/secret)
    if API_KEY and API_SECRET:
        balances = client.get_wallet_balances()
        print("Wallet:", "OK" if balances.get("success") else balances)
    else:
        print("Set DELTA_API_KEY and DELTA_API_SECRET for wallet/orders.")


if __name__ == "__main__":
    main()
