# Chat-completions style API shared by OpenAI (GPT) and xAI (Grok).
class Llm::OpenAiCompatible < Llm::Base
  def complete(prompt, system: nil, max_tokens: 1024, json: false)
    messages = [ ({ role: "system", content: system } if system), { role: "user", content: prompt } ].compact
    payload = { model: model, messages: messages, max_tokens: max_tokens }
    payload[:response_format] = { type: "json_object" } if json

    body = post_json(@base_url || endpoint, headers: { "Authorization" => "Bearer #{@api_key}" }, body: payload)
    body.dig("choices", 0, "message", "content").presence || raise(Llm::Error, "#{provider_name} returned no text")
  end

  private

  def endpoint = raise(NotImplementedError)
end
