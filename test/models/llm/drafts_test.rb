require "test_helper"

class Llm::DraftsTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:answer, :calls) do
    def complete(prompt, **options)
      (self.calls ||= []) << [ prompt, options ]
      answer
    end
  end

  setup do
    @topic = topics(:refresh_tokens)
    @topic.messages.create!(author: users(:jonas), body: "Reproduced on staging.")
  end

  test "task draft parses the model's JSON and sends the whole discussion" do
    client = FakeClient.new({ title: "Fix silent refresh-token expiry", description: "Summary\n\nWhat we agreed\n- Use a sliding window" }.to_json)
    draft = Llm::Drafts.task(@topic, client: client)

    assert_equal "Fix silent refresh-token expiry", draft.title
    assert_includes draft.description, "- Use a sliding window"
    prompt, options = client.calls.first
    assert_includes prompt, @topic.title
    assert_includes prompt, "Jonas K.: Reproduced on staging."
    assert options[:json]
    assert_includes options[:system], "ShipUp"
  end

  test "task draft falls back to the topic title when the model omits one" do
    draft = Llm::Drafts.task(@topic, client: FakeClient.new('{"description": "x"}'))
    assert_equal @topic.title, draft.title
  end

  test "JSON wrapped in code fences or prose is still understood" do
    fenced = "```json\n{\"title\": \"A\", \"description\": \"B\"}\n```"
    assert_equal "A", Llm::Drafts.task(@topic, client: FakeClient.new(fenced)).title
    assert_equal "A", Llm::Drafts.task(@topic, client: FakeClient.new("Sure! {\"title\": \"A\", \"description\": \"B\"} Hope that helps")).title
  end

  test "garbage is an Llm::Error, not a crash" do
    assert_raises(Llm::Error) { Llm::Drafts.task(@topic, client: FakeClient.new("I cannot do that")) }
  end

  test "chain draft returns ordered steps with estimates and skips empty ones" do
    answer = { title: "Fix expiry", steps: [ { title: "Backend", description: "Limits", days: 3 }, { title: "", description: "ignored" },
                                            { title: "QA", description: "Soak", days: "1.5" }, { title: "Docs" } ] }.to_json
    draft = Llm::Drafts.chain(@topic, client: FakeClient.new(answer))

    assert_equal "Fix expiry", draft.title
    assert_equal %w[Backend QA Docs], draft.steps.map { |step| step[:title] }
    assert_equal [ 3.0, 1.5, nil ], draft.steps.map { |step| step[:days] }
  end

  test "a chain draft without steps is an error" do
    assert_raises(Llm::Error) { Llm::Drafts.chain(@topic, client: FakeClient.new('{"title": "x", "steps": []}')) }
  end

  test "very long discussions are trimmed to the context budget" do
    @topic.messages.create!(author: users(:ines), body: "word " * 10_000)
    assert_operator Llm::Drafts.conversation(@topic).length, :<=, Llm::Drafts::MAX_CONTEXT
  end
end
