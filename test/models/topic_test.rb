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
