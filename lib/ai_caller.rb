# frozen_string_literal: true

module AiCaller
  module_function

  # Returns AI response string or nil on error.
  # provider: 'openai' | 'ollama'
  # model: optional; defaults to gpt-4o (openai) or llama3 (ollama)
  # timeout: optional; Ollama only, seconds (default from OLLAMA_TIMEOUT or 30)
  # system_prompt: optional; sets role/instructions (OpenAI: system message; Ollama: prepended to prompt)
  def call(prompt, provider: 'openai', model: nil, timeout: nil, system_prompt: nil)
    case provider.to_s.downcase
    when 'openai' then call_openai(prompt, model: model, system_prompt: system_prompt)
    when 'ollama' then call_ollama(prompt, model: model, timeout: timeout, system_prompt: system_prompt)
    else raise ArgumentError, "Unsupported AI provider: #{provider}"
    end
  end

  def call_openai(prompt, model: nil, system_prompt: nil)
    api_key = ENV.fetch('OPENAI_API_KEY', nil)
    raise 'OPENAI_API_KEY not set' if api_key.nil? || api_key.empty?

    require 'openai'
    client = OpenAI::Client.new(access_token: api_key)
    messages = if system_prompt.to_s.strip.empty?
                 [{ role: 'user', content: prompt }]
               else
                 [{ role: 'system', content: system_prompt.strip }, { role: 'user', content: prompt }]
               end
    params = {
      model: model || ENV.fetch('OPENAI_MODEL', 'gpt-4o'),
      messages: messages
    }
    resp = client.chat(parameters: params)
    content = resp.dig('choices', 0, 'message', 'content') || resp.dig(:choices, 0, :message, :content)
    content.to_s.strip
  end

  def call_ollama(prompt, model: nil, timeout: nil, system_prompt: nil)
    require 'ollama_client'

    config = Ollama::Config.new
    config.base_url = ENV.fetch('OLLAMA_HOST', 'http://localhost:11434')
    config.model = model || ENV.fetch('OLLAMA_MODEL', 'llama3')
    config.timeout = (timeout || ENV.fetch('OLLAMA_TIMEOUT', '30')).to_i

    client = Ollama::Client.new(config: config)
    full_prompt = system_prompt.to_s.strip.empty? ? prompt : "#{system_prompt.strip}\n\n---\n\n#{prompt}"
    result = client.generate(prompt: full_prompt)
    text = result.is_a?(Hash) ? (result['response'] || result[:response]) : result
    text.to_s.strip
  end
end
