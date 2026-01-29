# frozen_string_literal: true

require 'json'
require 'fileutils'

# Logs Delta AI suggestions (bias, reason, action, levels) to JSONL for later verification.
# Log file: log/delta_ai_actions.jsonl. Disable with DELTA_LOG_ACTIONS=0.
module DeltaActionLogger
  module_function

  def log_dir
    File.join(File.dirname(__dir__, 2), 'log')
  end

  def log_path
    File.join(log_dir, 'delta_ai_actions.jsonl')
  end

  def enabled?
    ENV.fetch('DELTA_LOG_ACTIONS', '1').strip != '0'
  end

  # Extract price levels only from the Action line to avoid RSI(50), SMA(20), etc.
  # Use symbol to keep only plausible price ranges (BTC ~1e4–1e5, ETH ~1e3–1e4).
  def levels_from_action(action_text, symbol)
    return [] if action_text.to_s.strip.empty?

    # Match full numbers: 87999.5 or 87,999.5 (not split into 879 and 99.5)
    raw = action_text.scan(/\d+(?:,\d{3})*(?:\.\d+)?|(?:\d+\.\d+)/).map { |s| s.delete(',').to_f }.uniq
    return raw if raw.empty?

    # Plausible price range per symbol; drop indicator values (14, 20, 50)
    range = case symbol.to_s
            when 'BTCUSD' then (1_000..500_000)
            when 'ETHUSD' then (100..50_000)
            else (10..1_000_000)
            end
    raw.select { |n| range.cover?(n) && ![14, 20, 50].include?(n) }
  end

  def parse_verdict(raw, symbol = nil)
    return { bias: nil, reason: nil, action: nil, levels: [] } if raw.to_s.strip.empty?

    text = raw.strip
    bias = text.match(/\bBias:\s*(Long|Short|No\s*trade)/i)&.captures&.first
    reason = text.match(/\bReason:\s*(.+?)(?=\s*•|\s*Action:|\z)/im)&.captures&.first&.strip
    action = text.match(/\bAction:\s*(.+?)\z/im)&.captures&.first&.strip
    levels = levels_from_action(action, symbol)

    { bias: bias, reason: reason, action: action, levels: levels }
  end

  def log(symbol, data, ai_response)
    return unless enabled?

    parsed = parse_verdict(ai_response, symbol)
    record = {
      at: Time.now.utc.iso8601(3),
      symbol: symbol,
      mark_price: data[:mark_price],
      index_price: data[:spot_price],
      funding_pct: (data[:funding_rate].to_f * 100).round(4),
      oi: data[:oi].to_s,
      rsi_14: data[:rsi_14],
      sma_20: data[:sma_20],
      trend: data[:trend].to_s,
      smc_summary: data[:smc_summary].to_s,
      ai_verdict: ai_response.to_s.strip,
      bias: parsed[:bias],
      reason: parsed[:reason],
      action: parsed[:action],
      levels: parsed[:levels]
    }
    FileUtils.mkdir_p(log_dir)
    File.open(log_path, 'a') { |f| f.puts(record.to_json) }
  end
end
