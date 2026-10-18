# Anthropic Messages API.
class Llm::Claude < Llm::Base
  ENDPOINT = "https://api.anthropic.com/v1/messages".freeze
  VERSION = "2023-06-01".freeze

  def complete(prompt, system: nil, max_tokens: 1024, json: false)
    system = [ system, ("Reply with a single valid JSON object and nothing else." if json) ].compact.join("\n\n").presence
    body = post_json(@base_url || ENDPOINT, headers: { "x-api-key" => @api_key, "anthropic-version" => VERSION },
                     body: { model: model, max_tokens: max_tokens, system: system, messages: [ { role: "user", content: prompt } ] }.compact)
    text = body.fetch("content", []).filter_map { |block| block["text"] if block["type"] == "text" }.join
    text.presence || raise(Llm::Error, "claude returned no text")
  end

  def initialize(api_key:, model: nil, base_url: nil)
    super
    @model = self.class.normalize_model(@model)
  end

  private

  def default_model = "claude-sonnet-5-5"

  # Accepts friendly names from .env ("sonnet-5.5", "Claude Sonnet 5.5") and turns them into API ids ("claude-sonnet-5-5").
  def self.normalize_model(name)
    id = name.to_s.strip.downcase.gsub(/[\s._]+/, "-")
    id.start_with?("claude-") ? id : "claude-#{id}"
  end
end
