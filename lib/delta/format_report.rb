# frozen_string_literal: true

# Formatted console and Telegram output for Delta perpetual analysis.
module FormatDeltaReport
  module_function

  WIDTH = 44
  LABEL_W = 14
  RULER = '─' * WIDTH
  RULER_HEAVY = '═' * WIDTH

  def num(v)
    return '—' if v.nil?
    return v.to_s unless v.is_a?(Numeric)
    return v.round(2).to_s if v.abs < 1000

    v.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def row(label, value)
    format("  %-#{LABEL_W}s  %s", label.to_s, value.to_s)
  end

  def section_title(symbol)
    title = "#{symbol} Perpetual · Delta Exchange"
    format("  ╭#{'─' * (WIDTH - 2)}╮\n  │ %-#{WIDTH - 4}s │\n  ╰#{'─' * (WIDTH - 2)}╯", title)
  end

  def format_console(symbol, data, ai_response)
    funding_pct = (data[:funding_rate].to_f * 100).round(4)
    verdict = (ai_response || '').to_s.strip.gsub(/\n+/, ' ').strip
    verdict = '— No AI verdict' if verdict.empty?
    smc = (data[:smc_summary] || '—').to_s

    lines = []
    lines << ''
    lines << section_title(symbol)
    lines << ''
    lines << '  Market'
    lines << row('Mark', num(data[:mark_price]))
    lines << row('Index (ref)', num(data[:spot_price]))
    lines << row('Funding', "#{funding_pct}%")
    lines << row('OI', data[:oi].to_s)
    lines << row('Chg 24h', "#{data[:mark_change_24h]}%")
    lines << "  #{RULER}"
    lines << '  Indicators'
    lines << row('RSI(14)', num(data[:rsi_14]))
    lines << row('SMA(20)', num(data[:sma_20]))
    lines << row('Trend', data[:trend].to_s)
    lines << "  #{RULER}"
    lines << '  SMC'
    lines << row('', smc)
    lines << "  #{RULER}"
    lines << '  Verdict'
    lines << "  #{verdict}"
    lines << ''
    lines << "  #{RULER_HEAVY}"
    lines.join("\n")
  end

  # Compact one-block summary for Telegram (readable, no box-drawing).
  def format_telegram(symbol, data, ai_response)
    funding_pct = (data[:funding_rate].to_f * 100).round(4)
    verdict = (ai_response || '').to_s.strip.gsub(/\n+/, ' ').strip
    verdict = '—' if verdict.empty?

    <<~MSG
      #{symbol} Perp · Delta
      Mark #{num(data[:mark_price])} · Index #{num(data[:spot_price])}
      Funding #{funding_pct}% · OI #{data[:oi]} · Chg24h #{data[:mark_change_24h]}%
      RSI #{num(data[:rsi_14])} · #{data[:trend]}
      SMC: #{data[:smc_summary] || '—'}

      → #{verdict}
    MSG
  end
end
