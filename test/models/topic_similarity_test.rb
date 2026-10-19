require "test_helper"

class TopicSimilarityTest < ActiveSupport::TestCase
  setup do
    @project = projects(:apollo)
    @refresh = topics(:refresh_tokens) # "Refresh tokens expire silently after 24h" / "Partners report 401s exactly 24h after authorizing."
  end

  def similar(title, body: "", exclude: nil)
    TopicSimilarity.new(project: @project, title: title, body: body, exclude: exclude).matches
  end

  test "finds a topic from a half-typed title, best match first, with a percentage" do
    @project.topics.create!(author: users(:ines), title: "Webhook retries with backoff")
    matches = similar("Refresh tokens expiring silently")

    assert_equal @refresh, matches.first.topic
    assert_operator matches.first.percent, :>, 30
    assert_not_includes matches.map { |match| match.topic.title }, "Webhook retries with backoff"
  end

  test "an identical title is 100% and a longer sibling scores clearly lower" do
    long = @project.topics.create!(author: users(:ines), title: "Refresh tokens expire silently after 24h on mobile")
    matches = similar("Refresh tokens expire silently after 24h")

    assert_equal 100, matches.find { |match| match.topic == @refresh }.percent
    assert_operator matches.find { |match| match.topic == long }.percent, :<, 90
  end

  test "a single shared word is only a weak match, never 100%" do
    assert_operator similar("tokens").map(&:percent).max.to_i, :<, 60
  end

  test "unrelated text matches nothing" do
    assert_empty similar("quarterly billing export")
  end

  test "the discussion counts, not just the title" do
    @refresh.messages.create!(author: users(:ines), body: "Looks like the rotation job never reschedules the sandbox credentials.")
    matches = similar("sandbox credentials rotation")

    assert_equal @refresh, matches.first&.topic
  end

  test "words typed in the post are compared too" do
    matches = similar("Sessions drop", body: "Partners report 401s exactly after authorizing")
    assert_equal @refresh, matches.first&.topic
  end

  test "replies written later change the result at once" do
    assert_empty similar("invoice reminder emails")
    @refresh.messages.create!(author: users(:jonas), body: "Same story with invoice reminder emails, they stop after a day.")
    assert_equal @refresh, similar("invoice reminder emails").first&.topic
  end

  test "removed replies are ignored" do
    reply = @refresh.messages.create!(author: users(:ines), body: "Unique zeppelin hangar logistics.")
    reply.remove!
    assert_empty similar("zeppelin hangar logistics")
  end

  test "a topic's related topics exclude itself and use its whole discussion" do
    sibling = @project.topics.create!(author: users(:ines), title: "Silent token failures on mobile", body: "refresh tokens expire after a day")
    related = TopicSimilarity.for_topic(@refresh).matches

    assert_includes related.map(&:topic), sibling
    assert_not_includes related.map(&:topic), @refresh
  end

  test "plurals and verb endings match" do
    sibling = @project.topics.create!(author: users(:ines), title: "Redirecting coaches fails")
    assert_includes similar("redirects coach failing").map(&:topic), sibling
  end

  test "very short input finds nothing" do
    assert_empty similar("re")
  end
end
