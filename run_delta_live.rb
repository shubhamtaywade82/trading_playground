#!/usr/bin/env ruby
# frozen_string_literal: true

# Delta Exchange futures: sub-agent pipeline (MarketData → Analysis → Thinking → Risk → Execution).
# Uses Ollama by default for professional-trader verdicts; optional live execution when LIVE_TRADING=1.
#
# Dry-run (default): no orders, only analysis and AI verdicts.
# Live: set LIVE_TRADING=1, DELTA_API_KEY, DELTA_API_SECRET, DELTA_MAX_POSITION_USD.
#
# Usage:
#   ruby run_delta_live.rb              # single cycle
#   LOOP_INTERVAL=300 ruby run_delta_live.rb   # every 5 minutes

require 'dotenv'
Dotenv.load(File.expand_path('.env', __dir__))

require_relative 'lib/delta/client'
require_relative 'lib/delta/orchestrator'

orchestrator = Delta::Orchestrator.new
loop_interval = ENV['LOOP_INTERVAL']&.strip&.to_i

if loop_interval&.positive?
  loop do
    puts "\n  ═════════════════════════════════════════════"
    puts "  Delta Live · #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    puts "  ═════════════════════════════════════════════"
    orchestrator.run_cycle
    puts "\n  End of cycle\n\n"
    sleep loop_interval
  rescue StandardError => e
    warn "Cycle error: #{e.message}"
    sleep loop_interval
  end
else
  puts "\n  ═════════════════════════════════════════════"
  puts "  Delta Live · #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
  puts "  ═════════════════════════════════════════════"
  orchestrator.run_cycle
  puts "\n  End of cycle\n\n"
end
