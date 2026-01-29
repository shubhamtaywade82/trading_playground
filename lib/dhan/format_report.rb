# frozen_string_literal: true

# Formatted console and Telegram output for Dhan (NIFTY/SENSEX) options analysis.
# Matches the visual style of Delta format_report for consistency.
module FormatDhanReport
  module_function

  WIDTH = 44
  LABEL_W = 14
  RULER = '─' * WIDTH
  RULER_HEAVY = '═' * WIDTH
  MAX_VERDICT_LEN = 280

  def num(v)
    return '—' if v.nil?
    return v.to_s unless v.is_a?(Numeric)
    return v.round(2).to_s if v.abs < 1000

    v.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def row(label, value)
    format("  %-#{LABEL_W}s  %s", label.to_s, value.to_s)
  end

  def levels_str(arr)
    return '—' if arr.nil? || !arr.is_a?(Array) || arr.empty?

    arr.map { |x| num(x) }.join(', ')
  end

  def section_title(symbol)
    title = "#{symbol} Options · Dhan"
    format("  ╭#{'─' * (WIDTH - 2)}╮\n  │ %-#{WIDTH - 4}s │\n  ╰#{'─' * (WIDTH - 2)}╯", title)
  end

  def format_verdict_block(raw)
    return '  — No AI verdict' if raw.to_s.strip.empty?

    text = raw.strip.gsub(/\n+/, ' ').strip.slice(0, MAX_VERDICT_LEN)
    text += '…' if raw.to_s.length > MAX_VERDICT_LEN
    parts = text.split(/\s*•\s*/).map(&:strip).reject(&:empty?)
    return "  #{text}" if parts.size <= 1

    parts.map { |p| p.start_with?('•') ? "  #{p}" : "  • #{p}" }.join("\n")
  end

  def format_console(symbol, data, ai_response)
    pcr = data[:call_oi].to_i.positive? ? (data[:put_oi].to_f / data[:call_oi]).round(2) : 0.0
    verdict = format_verdict_block(ai_response)
    levels = data[:key_levels] || {}

    lines = []
    lines << ''
    lines << section_title(symbol)
    lines << ''
    lines << '  Market'
    lines << row('Spot', num(data[:spot_price]))
    lines << row('PCR', num(pcr))
    lines << row('Nearest expiry', (data[:nearest_expiry] || '—').to_s)
    lines << row('Call OI', data[:call_oi].to_s)
    lines << row('Put OI', data[:put_oi].to_s)
    lines << row('ATM IV CE', num(data[:atm_iv_ce]))
    lines << row('ATM IV PE', num(data[:atm_iv_pe]))
    lines << row('OC Vol', (data[:total_volume].to_i.positive? ? data[:total_volume].to_s : '—'))
    lines << row('Chg %', (data[:last_change].nil? ? '—' : "#{data[:last_change]}%"))
    lines << "  #{RULER}"
    lines << '  Key levels'
    lines << row('Resistance', levels_str(levels[:resistance]))
    lines << row('Support', levels_str(levels[:support]))
    lines << "  #{RULER}"
    lines << '  LT (5m)'
    lines << row('RSI(14)', num(data[:rsi_14]))
    lines << row('SMA(20)', num(data[:sma_20]))
    lines << row('Trend', (data[:trend] || '—').to_s)
    lines << "  #{RULER}"
    lines << '  SMC'
    lines << row('', (data[:smc_summary] || '—').to_s)
    lines << "  #{RULER}"
    lines << '  Chart pattern'
    lines << row('', (data[:pattern_summary] || '—').to_s)
    lines << "  #{RULER}"
    lines << '  Verdict'
    lines << verdict
    lines << ''
    lines << "  #{RULER_HEAVY}"
    lines.join("\n")
  end

  def format_telegram(symbol, data, ai_response)
    pcr = data[:call_oi].to_i.positive? ? (data[:put_oi].to_f / data[:call_oi]).round(2) : 0.0
    raw = (ai_response || '').to_s.strip
    verdict = if raw.empty?
                '—'
              else
                raw.gsub(/\n+/, ' ').strip.split(/\s*•\s*/).map(&:strip).reject(&:empty?).map do |p|
                  p.start_with?('•') ? p : "• #{p}"
                end.join("\n      ")
              end
    levels = data[:key_levels] || {}
    res = levels_str(levels[:resistance])
    sup = levels_str(levels[:support])

    iv_tg = [data[:atm_iv_ce], data[:atm_iv_pe]].any? ? " · IV #{num(data[:atm_iv_ce])}/#{num(data[:atm_iv_pe])}" : ''
    vol_tg = data[:total_volume].to_i.positive? ? " · Vol #{data[:total_volume]}" : ''
    <<~MSG
      #{symbol} Options · Dhan
      Spot #{num(data[:spot_price])} · PCR #{num(pcr)} · RSI #{num(data[:rsi_14])} · #{data[:trend]} · Chg #{data[:last_change]}%#{iv_tg}#{vol_tg}
      R:#{res} S:#{sup}
      SMC: #{data[:smc_summary] || '—'}

      → #{verdict}
    MSG
  end
end
