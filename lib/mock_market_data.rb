# frozen_string_literal: true

require 'date'

# Returns fake market data per symbol for testing prompt + AI without Dhan API.
# Enable with MOCK_DATA=1.
module MockMarketData
  module_function

  def data(symbol)
    base = symbol.to_s == 'SENSEX' ? 72_000 : 24_500
    {
      spot_price: base + rand(-100..100),
      current_ohlc_str: "#{base}/#{base + 50}/#{base - 30}/#{base + 20}",
      nearest_expiry: (Date.today + 7).to_s,
      call_oi: rand(1_200_000..1_400_000),
      put_oi: rand(1_100_000..1_300_000),
      sma_20: base + rand(-30..30),
      rsi_14: rand(35..75),
      trend: ['Bullish (above SMA)', 'Bearish (below SMA)', 'Neutral'].sample,
      last_change: rand(-0.8..0.8).round(2)
    }
  end
end
