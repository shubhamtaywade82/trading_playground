# frozen_string_literal: true

# Delta trading sub-agents: market data, analysis, thinking (Ollama), risk, execution.
# Load all agents with: require_relative 'delta/agents'
require_relative 'agents/market_data_agent'
require_relative 'agents/analysis_agent'
require_relative 'agents/thinking_agent'
require_relative 'agents/risk_agent'
require_relative 'agents/execution_agent'
