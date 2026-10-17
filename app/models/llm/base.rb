# The adapter contract: `complete(prompt, ...)` returns the model's text answer.
class Llm::Base
  TIMEOUT = 45

  def initialize(api_key:, model: nil, base_url: nil)
    @api_key = api_key
    @model = model || default_model
    @base_url = base_url
  end

  attr_reader :model

  # prompt     - the user message
  # system     - optional instructions that frame the whole exchange
  # max_tokens - cap on the answer length
  # json       - ask for a JSON object (providers that support a JSON mode use it)
  def complete(prompt, system: nil, max_tokens: 1024, json: false)
    raise NotImplementedError, "#{self.class} must implement #complete"
  end

  def provider_name = self.class.name.demodulize.downcase

  private

  def default_model = raise(NotImplementedError)

  # POSTs JSON and returns the parsed body, turning any failure into Llm::Error.
  def post_json(url, headers:, body:)
    response = Faraday.new(request: { timeout: TIMEOUT, open_timeout: 10 }) { |f| f.response :json, content_type: /json/ }.post(url) do |request|
      request.headers.merge!(headers)
      request.headers["Content-Type"] = "application/json"
      request.body = body.to_json
    end
    raise Llm::Error, "#{provider_name} error (#{response.status}): #{error_message(response.body)}" unless response.success?

    response.body
  rescue Faraday::Error => error
    raise Llm::Error, "#{provider_name} request failed: #{error.message}"
  end

  def error_message(body)
    return body.to_s.truncate(200) unless body.is_a?(Hash)

    detail = body["error"]
    (detail.is_a?(Hash) ? detail["message"] : detail).to_s.presence || body.to_s.truncate(200)
  end
end
