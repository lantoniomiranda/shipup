require "test_helper"

class TopicTest < ActiveSupport::TestCase
  setup { @topic = topics(:refresh_tokens) }

  test "casting votes keeps the cached score in sync" do
    @topic.cast_vote(users(:ines), 1)
    @topic.cast_vote(users(:jonas), 1)
    assert_equal 2, @topic.reload.votes_score
  end

  test "voting the same way twice retracts the vote" do
    @topic.cast_vote(users(:ines), 1)
    @topic.cast_vote(users(:ines), 1)
    assert_equal 0, @topic.reload.votes_score
    assert_nil @topic.vote_by(users(:ines))
  end

  test "flipping a vote swings the score" do
    @topic.cast_vote(users(:ines), 1)
    @topic.cast_vote(users(:ines), -1)
    assert_equal(-1, @topic.reload.votes_score)
  end

  test "messages bump the reply counter and activity time" do
    @topic.messages.create!(author: users(:ines), body: "On it.")
    assert_equal 1, @topic.reload.messages_count
    assert_not_nil @topic.last_activity_at
  end

  test "orders by score for the top list" do
    other = projects(:apollo).topics.create!(author: users(:ines), title: "Dark mode", votes_score: 5)
    assert_equal other, projects(:apollo).topics.top.first
  end
end

class TopicSimilarityTest < ActiveSupport::TestCase
  test "ranks titles by trigram similarity with a percentage" do
    projects(:apollo).topics.create!(author: users(:ines), title: "Webhook retries with backoff")
    results = projects(:apollo).topics.similar_to("Refresh tokens expiring silently")

    assert_equal topics(:refresh_tokens), results.first
    assert_operator results.first.match_percent, :>, 30
    assert_not_includes results.map(&:title), "Webhook retries with backoff"
  end

  test "an identical title is 100% and a longer sibling scores clearly lower" do
    long = projects(:apollo).topics.create!(author: users(:ines), title: "Refresh tokens expire silently after 24h on mobile")
    results = projects(:apollo).topics.similar_to("Refresh tokens expire silently after 24h")

    assert_equal [ 100 ], results.select { |topic| topic.id == topics(:refresh_tokens).id }.map(&:match_percent)
    assert_operator results.find { |topic| topic.id == long.id }.match_percent, :<, 90
  end

  test "a single shared word is only a weak match, never 100%" do
    results = projects(:apollo).topics.similar_to("tokens")
    assert_operator results.map(&:match_percent).max.to_i, :<, 60
  end

  test "a half-typed title still finds its topic" do
    results = projects(:apollo).topics.similar_to("refresh tokens expire")
    assert_equal topics(:refresh_tokens), results.first
    assert_operator results.first.match_percent, :>=, 40
  end

  test "unrelated text matches nothing" do
    assert_empty projects(:apollo).topics.similar_to("quarterly billing export")
  end
end
