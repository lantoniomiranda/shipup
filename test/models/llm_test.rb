require "test_helper"

class LlmTest < ActiveSupport::TestCase
  include LlmHelper
  JSON_HEADERS = { "Content-Type" => "application/json" }.freeze

  test "AI is off unless a provider and key are set" do
    assert_not Llm.enabled?
    with_llm("gemini") { assert Llm.enabled? }
    with_llm("gemini", api_key: "") { assert_not Llm.enabled? }
    with_llm("skynet") { assert_not Llm.enabled? }
  end

  test "client raises a clear error when not configured" do
    assert_match(/Set LLM_ENABLED/, assert_raises(Llm::NotConfigured) { Llm.client }.message)
    with_llm("skynet") { assert_match(/Unknown LLM provider/, assert_raises(Llm::NotConfigured) { Llm.client }.message) }
    ENV["LLM_ENABLED"] = "gpt"
    assert_match(/LLM_API_KEY/, assert_raises(Llm::NotConfigured) { Llm.client }.message)
  ensure
    ENV.delete("LLM_ENABLED")
  end

  test "LLM_ENABLED selects the adapter, including aliases and any casing" do
    { "claude" => Llm::Claude, "Anthropic" => Llm::Claude, "GEMINI" => Llm::Gemini, "google" => Llm::Gemini,
      "grok" => Llm::Grok, "xai" => Llm::Grok, "gpt" => Llm::Gpt, "openai" => Llm::Gpt }.each do |name, adapter|
      with_llm(name) { assert_instance_of adapter, Llm.client, name }
    end
  end

  test "model and base url can be overridden" do
    with_llm("gpt", model: "gpt-5", base_url: "https://proxy.test/v1/chat") do
      stub = stub_request(:post, "https://proxy.test/v1/chat").with(body: hash_including("model" => "gpt-5"))
        .to_return(status: 200, body: { choices: [ { message: { content: "hi" } } ] }.to_json, headers: JSON_HEADERS)
      assert_equal "hi", Llm.client.complete("hello")
      assert_requested stub
    end
  end

  test "Claude sends the Messages API request and joins text blocks" do
    stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
      .with(headers: { "x-api-key" => "test-key", "anthropic-version" => "2023-06-01" },
            body: hash_including("model" => "claude-sonnet-5-5", "max_tokens" => 300, "system" => "Be brief.", "messages" => [ { "role" => "user", "content" => "Hi" } ]))
      .to_return(status: 200, body: { content: [ { type: "text", text: "Hello" }, { type: "text", text: " there" } ] }.to_json, headers: JSON_HEADERS)

    with_llm("claude") { assert_equal "Hello there", Llm.client.complete("Hi", system: "Be brief.", max_tokens: 300) }
    assert_requested stub
  end

  test "Claude is told to answer in JSON when json mode is on" do
    stub = stub_request(:post, "https://api.anthropic.com/v1/messages").with { |request| JSON.parse(request.body)["system"].include?("single valid JSON object") }
      .to_return(status: 200, body: { content: [ { type: "text", text: "{}" } ] }.to_json, headers: JSON_HEADERS)
    with_llm("claude") { Llm.client.complete("x", json: true) }
    assert_requested stub
  end

  test "Gemini sends generateContent with the key header and JSON mime type" do
    stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent")
      .with(headers: { "x-goog-api-key" => "test-key" },
            body: hash_including("contents" => [ { "role" => "user", "parts" => [ { "text" => "Hi" } ] } ],
                                 "systemInstruction" => { "parts" => [ { "text" => "Be brief." } ] },
                                 "generationConfig" => { "maxOutputTokens" => 500, "responseMimeType" => "application/json" }))
      .to_return(status: 200, body: { candidates: [ { content: { parts: [ { text: "{\"ok\":true}" } ] } } ] }.to_json, headers: JSON_HEADERS)

    with_llm("gemini") { assert_equal "{\"ok\":true}", Llm.client.complete("Hi", system: "Be brief.", max_tokens: 500, json: true) }
    assert_requested stub
  end

  test "Gemini explains an empty answer" do
    stub_request(:post, %r{generativelanguage}).to_return(status: 200, body: { candidates: [ { finishReason: "SAFETY" } ] }.to_json, headers: JSON_HEADERS)
    with_llm("gemini") { assert_match(/SAFETY/, assert_raises(Llm::Error) { Llm.client.complete("x") }.message) }
  end

  test "GPT and Grok use the chat completions shape with their own endpoints" do
    { "gpt" => [ "https://api.openai.com/v1/chat/completions", "gpt-4o-mini" ], "grok" => [ "https://api.x.ai/v1/chat/completions", "grok-3-mini" ] }.each do |name, (url, model)|
      stub = stub_request(:post, url)
        .with(headers: { "Authorization" => "Bearer test-key" },
              body: hash_including("model" => model, "response_format" => { "type" => "json_object" },
                                   "messages" => [ { "role" => "system", "content" => "Sys" }, { "role" => "user", "content" => "Hi" } ]))
        .to_return(status: 200, body: { choices: [ { message: { content: "answer from #{name}" } } ] }.to_json, headers: JSON_HEADERS)

      with_llm(name) { assert_equal "answer from #{name}", Llm.client.complete("Hi", system: "Sys", json: true) }
      assert_requested stub
    end
  end

  test "provider errors become Llm::Error with the provider's message" do
    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 429, body: { error: { message: "Rate limit reached" } }.to_json, headers: JSON_HEADERS)
    with_llm("gpt") do
      error = assert_raises(Llm::Error) { Llm.client.complete("x") }
      assert_match(/gpt error \(429\): Rate limit reached/, error.message)
    end
  end

  test "network failures become Llm::Error" do
    stub_request(:post, %r{api.anthropic.com}).to_timeout
    with_llm("claude") { assert_raises(Llm::Error) { Llm.client.complete("x") } }
  end

  test "new providers only need a subclass and a registry entry" do
    assert_equal Llm::Base, Llm::Claude.superclass
    assert_equal Llm::OpenAiCompatible, Llm::Gpt.superclass
    assert_raises(NotImplementedError) { Llm::Base.new(api_key: "k").complete("x") }
  end
end
