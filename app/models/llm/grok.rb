# xAI Grok (OpenAI-compatible).
class Llm::Grok < Llm::OpenAiCompatible
  private

  def endpoint = "https://api.x.ai/v1/chat/completions"
  def default_model = "grok-3-mini"
end
