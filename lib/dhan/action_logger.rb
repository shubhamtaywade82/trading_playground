# frozen_string_literal: true

require 'json'
require 'fileutils'

# Logs Dhan AI suggestions (bias, reason, action, levels) to JSONL for later verification.
# Log file: log/dhan_ai_actions.jsonl. Disable with DHAN_LOG_ACTIONS=0.
module DhanActionLogger
  module_function

  def log_dir
    File.join(File.dirname(__dir__, 2), 'log')
  end

  def log_path
    File.join(log_dir, 'dhan_ai_actions.jsonl')
  end

  def enabled?
    ENV.fetch('DHAN_LOG_ACTIONS', '1').strip != '0'
  end

  # Extract price levels from the Action line (e.g. "Wait for 25500" → [25500]).
  # Plausible index range: NIFTY ~22k–26k, SENSEX ~70k–86k.
  def levels_from_action(action_text, symbol)
    return [] if action_text.to_s.strip.empty?

    raw = action_text.scan(/\d+(?:,\d{3})*(?:\.\d+)?|(?:\d+\.\d+)/).map { |s| s.delete(',').to_f }.uniq
    return raw if raw.empty?

    range = case symbol.to_s
            when 'NIFTY' then (20_000..28_000)
            when 'SENSEX' then (65_000..90_000)
            else (10_000..100_000)
            end
    raw.select { |n| range.cover?(n) && ![14, 20].include?(n) }
  end

  def parse_verdict(raw, symbol = nil)
    return { bias: nil, reason: nil, action: nil, levels: [] } if raw.to_s.strip.empty?

    text = raw.strip
    bias = text.match(/\bBias:\s*(?:Buy\s+)?(CE|PE|No\s*trade)/i)&.captures&.first
    reason = text.match(/\bReason:\s*(.+?)(?=\s*•|\s*Action:|\z)/im)&.captures&.first&.strip
    action = text.match(/\bAction:\s*(.+?)\z/im)&.captures&.first&.strip
    levels = levels_from_action(action, symbol)

    { bias: bias, reason: reason, action: action, levels: levels }
  end

  def log(symbol, data, ai_response)
    return unless enabled?

    parsed = parse_verdict(ai_response.to_s, symbol)
    pcr = data[:call_oi].to_i.positive? ? (data[:put_oi].to_f / data[:call_oi]).round(4) : 0.0
    record = {
      at: Time.now.utc.iso8601(3),
      symbol: symbol,
      spot_price: data[:spot_price],
      pcr: pcr,
      call_oi: data[:call_oi].to_i,
      put_oi: data[:put_oi].to_i,
      atm_iv_ce: data[:atm_iv_ce],
      atm_iv_pe: data[:atm_iv_pe],
      total_volume: data[:total_volume].to_i,
      rsi_14: data[:rsi_14],
      sma_20: data[:sma_20],
      trend: data[:trend].to_s,
      last_change: data[:last_change],
      smc_summary: data[:smc_summary].to_s,
      pattern_summary: data[:pattern_summary].to_s,
      ai_verdict: ai_response.to_s.strip,
      bias: parsed[:bias],
      reason: parsed[:reason],
      action: parsed[:action],
      levels: parsed[:levels]
    }
    record[:nearest_expiry] = data[:nearest_expiry] if data[:nearest_expiry]
    key_levels = data[:key_levels]
    if key_levels.is_a?(Hash)
      record[:key_levels] = {
        resistance: Array(key_levels[:resistance]),
        support: Array(key_levels[:support])
      }
    end
    FileUtils.mkdir_p(log_dir)
    File.open(log_path, 'a') { |f| f.puts(record.to_json) }
  end
end
