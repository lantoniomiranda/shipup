# OpenAI chat completions.
class Llm::Gpt < Llm::OpenAiCompatible
  private

  def endpoint = "https://api.openai.com/v1/chat/completions"
  def default_model = "gpt-4o-mini"
end
