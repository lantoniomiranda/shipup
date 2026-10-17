# Provider-agnostic LLM access. Pick the provider with environment variables:
#
#   LLM_ENABLED=gemini          claude | gemini | grok | gpt   (unset or blank = AI features off)
#   LLM_API_KEY=...             the provider's API key
#   LLM_MODEL=...               optional; each adapter has a sensible default
#   LLM_BASE_URL=...            optional; point at a proxy or an OpenAI-compatible gateway
#
# Application code only ever calls `Llm.client.complete(...)` (or checks `Llm.enabled?`), so
# switching provider is a configuration change. To add a provider, subclass Llm::Base and register
# it in ADAPTERS.
module Llm
  class Error < StandardError; end
  class NotConfigured < Error; end

  ADAPTERS = {
    "claude" => "Llm::Claude", "anthropic" => "Llm::Claude",
    "gemini" => "Llm::Gemini", "google" => "Llm::Gemini",
    "grok" => "Llm::Grok", "xai" => "Llm::Grok",
    "gpt" => "Llm::Gpt", "openai" => "Llm::Gpt"
  }.freeze

  module_function

  def provider = ENV["LLM_ENABLED"].to_s.strip.downcase.presence

  def enabled?
    provider.present? && ENV["LLM_API_KEY"].present? && ADAPTERS.key?(provider)
  end

  # A ready adapter for the configured provider. Raises NotConfigured when AI is off or misconfigured.
  def client
    raise NotConfigured, "Set LLM_ENABLED (#{ADAPTERS.keys.uniq.join(", ")}) to use AI features" if provider.blank?
    raise NotConfigured, "Unknown LLM provider #{provider.inspect}" unless ADAPTERS.key?(provider)
    raise NotConfigured, "Set LLM_API_KEY for #{provider}" if ENV["LLM_API_KEY"].blank?

    ADAPTERS.fetch(provider).constantize.new(api_key: ENV["LLM_API_KEY"], model: ENV["LLM_MODEL"].presence, base_url: ENV["LLM_BASE_URL"].presence)
  end
end
