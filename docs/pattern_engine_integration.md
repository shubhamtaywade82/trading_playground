# Options-Buying Pattern Engine — Integration

One vertical slice: **data → analysis → decision → execution**. No hand-waving; same logic as the rulebook.

**Rulebook:** [pattern_detection_rulebook.md](pattern_detection_rulebook.md)

---

## Layout (as integrated)

```
lib/
├── candle.rb              # Candle = Struct(timestamp, open, high, low, close, volume)
├── candle_series.rb       # CandleSeries.load(symbol, :m15) from data/candles/*.csv
├── indicators/
│   ├── atr.rb
│   ├── ema.rb
│   ├── rsi.rb
│   └── volume_metrics.rb
├── market_context/
│   ├── trend_detector.rb   # 60m EMA 50 vs 200
│   └── volatility_filter.rb # 15m ATR > median
├── patterns/
│   ├── base_pattern.rb    # valid? / direction
│   ├── swing_detector.rb
│   ├── head_and_shoulders.rb
│   ├── double_top_bottom.rb
│   ├── triangle.rb
│   ├── flag_pennant.rb
│   └── engulfing.rb
├── options/
│   ├── option_filters.rb  # IV < 70, dte >= 2
│   └── strike_selector.rb # ATM ± offset
└── engine/
    ├── pattern_engine.rb  # Runs PATTERNS, returns first valid
    ├── pattern_signal.rb  # Direction, SL, TP; execute = placeholder
    └── execution_pipeline.rb # Volatility → Trend → Pattern → MTF → Options → Signal

data/candles/              # index_1m.csv, index_5m.csv, index_15m.csv, index_60m.csv
run_pattern_engine.rb      # Entry: loads candles, calls ExecutionPipeline
```

---

## Data contract

- **Candle:** `Struct.new(:timestamp, :open, :high, :low, :close, :volume)` (keyword_init).
- **Load:** `CandleSeries.load(:index, :m15)` → array of `Candle`. Reads `data/candles/index_15m.csv` if present.
- **From arrays:** `CandleSeries.from_ohlcv_arrays(opens:, highs:, lows:, closes:, volumes:)` for DhanHQ/Delta.

---

## Run

```bash
# With CSV under data/candles/
ruby run_pattern_engine.rb

# Env: PATTERN_SYMBOL=index, IV_PERCENTILE=50, DTE=3, SUPPORT_LEVEL=29200, RESISTANCE_LEVEL=29500
```

From code:

```ruby
context = {
  candles_60m: candles_60m,
  candles_15m: candles_15m,
  candles_5m:  candles_5m,
  candles_1m:  candles_1m,
  iv_percentile: 50,
  dte: 3,
  support_level: 29200,
  resistance_level: 29500
}
result = ExecutionPipeline.call(context)
# result = { direction:, pattern:, sl:, tp: } or nil
```

---

## Next (pick one)

1. **Wire DhanHQ order execution** — replace `PatternSignal#execute` with DhanHQ place order.
2. **OI + index volume filters** — already in `lib/pattern_detection/`; reuse or port into this slice.
3. **Backtest** — replay CSV or historical API into `ExecutionPipeline.call`.
4. **Rails API** — wrap `ExecutionPipeline.call` in a controller/service.
