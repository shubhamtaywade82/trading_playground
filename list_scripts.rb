#!/usr/bin/env ruby
# frozen_string_literal: true

# Lists runnable scripts and how to run them with AI analysis.
# Usage: ruby list_scripts.rb

SCRIPTS = [
  {
    name: 'Dhan (NIFTY/SENSEX options)',
    script: 'generate_ai_prompt.rb',
    data: 'Dhan API: option chain, 5m OHLC, PCR, SMA, RSI, SMC, chart pattern. Focus: options buying — buy CE (bullish) / PE (bearish). NIFTY/SENSEX.',
    ai: 'AI_PROVIDER=ollama or AI_PROVIDER=openai',
    run: 'ruby generate_ai_prompt.rb',
    run_with_ai: 'AI_PROVIDER=ollama ruby generate_ai_prompt.rb',
    symbols_env: 'UNDERLYINGS (default: NIFTY,SENSEX) or UNDERLYING=NIFTY',
    list_symbols: 'UNDERLYINGS=NIFTY,SENSEX (comma-separated; or use Dhan instrument master for more)'
  },
  {
    name: 'Delta (crypto perpetuals)',
    script: 'generate_ai_prompt_delta.rb',
    data: 'Delta API: ticker, 5m/1h candles, funding, OI, orderbook, SMC, key levels, chart pattern.',
    ai: 'AI_PROVIDER=ollama or AI_PROVIDER=openai',
    run: 'ruby generate_ai_prompt_delta.rb',
    run_with_ai: 'AI_PROVIDER=ollama ruby generate_ai_prompt_delta.rb',
    symbols_env: 'DELTA_SYMBOLS (default: BTCUSD,ETHUSD)',
    list_symbols: 'DELTA_SYMBOLS=BTCUSD,ETHUSD,SOLUSD (comma-separated)'
  },
  {
    name: 'Delta live pipeline (AI + optional execution)',
    script: 'run_delta_live.rb',
    data: 'Delta API (ticker, 5m/1h candles, orderbook) → Analysis → Thinking (Ollama) → Risk → Execution',
    ai: 'Uses Ollama by default (DELTA_AI_TIMEOUT, OLLAMA_MODEL). Set LIVE_TRADING=1 for real orders.',
    run: 'ruby run_delta_live.rb',
    run_with_ai: 'ruby run_delta_live.rb   # AI analysis is built-in',
    symbols_env: 'DELTA_SYMBOLS (default: BTCUSD,ETHUSD)',
    list_symbols: 'DELTA_SYMBOLS=BTCUSD,ETHUSD or list products: see below'
  },
  {
    name: 'Pattern engine (chart patterns → signal)',
    script: 'run_pattern_engine.rb',
    data: 'Chart patterns (engulfing, H&S, double top/bottom, triangle, flag). Run for NIFTY and SENSEX: PATTERN_SYMBOLS=NIFTY,SENSEX PATTERN_SECURITY_IDS=13,51.',
    ai: 'No AI; outputs direction/SL/TP per symbol. Same patterns are also checked in generate_ai_prompt (Dhan) and generate_ai_prompt_delta (Delta).',
    run: 'ruby run_pattern_engine.rb',
    run_with_ai: 'N/A (pattern-only). Use CANDLE_SOURCE=delta PATTERN_SYMBOL=BTCUSD for Delta candles.',
    symbols_env: 'PATTERN_SYMBOL (e.g. index, BTCUSD); for Dhan: PATTERN_SECURITY_ID',
    list_symbols: 'Delta: PATTERN_SYMBOL=BTCUSD. Dhan index: PATTERN_SECURITY_ID=13 PATTERN_EXCHANGE_SEGMENT=IDX_I PATTERN_INSTRUMENT=INDEX.'
  }
].freeze

def main
  puts "\n  ═══════════════════════════════════════════════════════════"
  puts "  Trading Playground — Scripts & AI analysis"
  puts "  ═══════════════════════════════════════════════════════════\n"

  SCRIPTS.each_with_index do |s, i|
    puts "  #{i + 1}. #{s[:name]}"
    puts "     Script:    #{s[:script]}"
    puts "     Data:      #{s[:data]}"
    puts "     AI:        #{s[:ai]}"
    puts "     Run:       #{s[:run]}"
    puts "     With AI:   #{s[:run_with_ai]}"
    puts "     Symbols:   #{s[:symbols_env]}"
    puts "     List:      #{s[:list_symbols]}"
    puts ""
  end

  puts "  How to list Delta products (symbols):"
  puts '     ruby -r ./lib/delta/client -e "c = DeltaExchangeClient.new; r = c.products(contract_types: \'perpetual_futures\', states: \'live\'); puts (r[\'result\']||[]).map { |p| p[\'symbol\'] }.join(\"\\n\")"'
  puts ""
  puts "  How to list Dhan underlyings:"
  puts "     Set UNDERLYINGS=NIFTY,SENSEX (or use Dhan instrument master / MCP search_instruments)."
  puts ""
end

main
