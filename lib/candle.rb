# frozen_string_literal: true

# Data contract: every module consumes the same candle shape.
# Timeframes passed explicitly. No globals.
Candle = Struct.new(:timestamp, :open, :high, :low, :close, :volume, keyword_init: true) do
  def self.from_hash(h)
    new(
      timestamp: h[:timestamp] || h['timestamp'],
      open: (h[:open] || h['open']).to_f,
      high: (h[:high] || h['high']).to_f,
      low: (h[:low] || h['low']).to_f,
      close: (h[:close] || h['close']).to_f,
      volume: (h[:volume] || h['volume']).to_f
    )
  end
end
