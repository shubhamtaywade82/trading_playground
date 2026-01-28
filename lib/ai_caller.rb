# frozen_string_literal: true

require 'json'
require 'net/http'

module AiCaller
  module_function

  # Returns AI response string or nil on error.
  # provider: 'openai' | 'ollama'
  # model: optional; defaults to gpt-4o (openai) or llama3 (ollama)
  def call(prompt, provider: 'openai', model: nil)
    case provider.to_s.downcase
    when 'openai' then call_openai(prompt, model: model)
    when 'ollama' then call_ollama(prompt, model: model)
    else raise ArgumentError, "Unsupported AI provider: #{provider}"
    end
  end

  def call_openai(prompt, model: nil)
    api_key = ENV['OPENAI_API_KEY']
    raise 'OPENAI_API_KEY not set' if api_key.nil? || api_key.empty?

    require 'openai'
    client = OpenAI::Client.new(access_token: api_key)
    params = {
      model: model || ENV.fetch('OPENAI_MODEL', 'gpt-4o'),
      messages: [{ role: 'user', content: prompt }]
    }
    resp = client.chat(parameters: params)
    content = resp.dig('choices', 0, 'message', 'content') || resp.dig(:choices, 0, :message, :content)
    content.to_s.strip
  end

  def call_ollama(prompt, model: nil)
    base_url = ENV.fetch('OLLAMA_HOST', 'http://localhost:11434')
    model ||= ENV.fetch('OLLAMA_MODEL', 'llama3')
    uri      = URI("#{base_url.chomp('/')}/api/generate")
    req      = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/json'
    req.body = { model: model, prompt: prompt, stream: false }.to_json

    resp = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 60) { |http| http.request(req) }
    raise "Ollama request failed: #{resp.code}" unless resp.is_a?(Net::HTTPSuccess)

    body = JSON.parse(resp.body)
    body['response'].to_s.strip
  end
end
