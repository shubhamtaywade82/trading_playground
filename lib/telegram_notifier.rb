# frozen_string_literal: true

require 'net/http'
require 'uri'

# Sends messages to Telegram (same pattern as algo_trading_api TelegramNotifier).
# Requires TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID.
module TelegramNotifier
  TELEGRAM_API = 'https://api.telegram.org'
  MAX_LEN      = 4000

  def self.send_message(text, chat_id: nil)
    return if text.to_s.strip.empty?

    chat_id ||= ENV.fetch('TELEGRAM_CHAT_ID', nil)
    return unless chat_id

    token = ENV.fetch('TELEGRAM_BOT_TOKEN', nil)
    unless token
      warn 'TelegramNotifier: TELEGRAM_BOT_TOKEN not set'
      return
    end

    chunks(text).each do |chunk|
      post(token, 'sendMessage', chat_id: chat_id, text: chunk)
    end
  end

  def self.chunks(text)
    return [] if text.to_s.strip.empty?

    lines = text.split("\n")
    buf = ''
    out = []

    lines.each do |line|
      candidate = buf.empty? ? line : "#{buf}\n#{line}"
      if candidate.length > MAX_LEN
        out << buf.strip unless buf.strip.empty?
        buf = line
      else
        buf = buf.empty? ? line : "#{buf}\n#{line}"
      end
    end
    out << buf.strip unless buf.strip.empty?
    out
  end

  def self.post(token, method, **params)
    uri = URI("#{TELEGRAM_API}/bot#{token}/#{method}")
    res = Net::HTTP.post_form(uri, params)

    warn "Telegram #{method} failed: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
    res
  rescue StandardError => e
    warn "Telegram #{method} error: #{e.message}"
  end
  private_class_method :post
end
