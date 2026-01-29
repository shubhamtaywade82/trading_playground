# frozen_string_literal: true

module AiCaller
  module_function

  # Returns AI response string or nil on error.
  # provider: 'openai' | 'ollama'
  # model: optional; defaults to gpt-4o (openai) or llama3 (ollama)
  # timeout: optional; Ollama only, seconds (default from OLLAMA_TIMEOUT or 30)
  def call(prompt, provider: 'openai', model: nil, timeout: nil)
    case provider.to_s.downcase
    when 'openai' then call_openai(prompt, model: model)
    when 'ollama' then call_ollama(prompt, model: model, timeout: timeout)
    else raise ArgumentError, "Unsupported AI provider: #{provider}"
    end
  end

  def call_openai(prompt, model: nil)
    api_key = ENV.fetch('OPENAI_API_KEY', nil)
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

  def call_ollama(prompt, model: nil, timeout: nil)
    require 'ollama_client'

    config = Ollama::Config.new
    config.base_url = ENV.fetch('OLLAMA_HOST', 'http://localhost:11434')
    config.model = model || ENV.fetch('OLLAMA_MODEL', 'llama3')
    config.timeout = (timeout || ENV.fetch('OLLAMA_TIMEOUT', '30')).to_i

    client = Ollama::Client.new(config: config)
    result = client.generate(prompt: prompt)
    text = result.is_a?(Hash) ? (result['response'] || result[:response]) : result
    text.to_s.strip
  end
end
