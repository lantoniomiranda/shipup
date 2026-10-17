# Google Gemini generateContent API.
class Llm::Gemini < Llm::Base
  ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models".freeze

  def complete(prompt, system: nil, max_tokens: 1024, json: false)
    generation = { maxOutputTokens: max_tokens }
    generation[:responseMimeType] = "application/json" if json
    payload = { contents: [ { role: "user", parts: [ { text: prompt } ] } ], generationConfig: generation }
    payload[:systemInstruction] = { parts: [ { text: system } ] } if system

    body = post_json("#{@base_url || ENDPOINT}/#{model}:generateContent", headers: { "x-goog-api-key" => @api_key }, body: payload)
    text = body.dig("candidates", 0, "content", "parts")&.filter_map { |part| part["text"] }&.join
    text.presence || raise(Llm::Error, "gemini returned no text#{" (#{body.dig("candidates", 0, "finishReason")})" if body.dig("candidates", 0, "finishReason")}")
  end

  private

  def default_model = "gemini-2.0-flash"
end
