require "test_helper"

class ChatMessageTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:rate_limiting)
    @first = @task.messages.create!(author: users(:jonas), body: "Counters are merged.")
    @project = projects(:apollo)
  end

  test "a reply quotes an earlier message of the same thread" do
    reply = @task.messages.create!(author: users(:ines), body: "Great, dashboard next.", parent: @first)
    assert_equal @first, reply.parent
    assert_equal [ reply ], @first.replies.to_a
  end

  test "a reply cannot quote a message from another thread" do
    other = tasks(:spec_published).messages.create!(author: users(:ines), body: "Elsewhere")
    reply = @task.messages.build(author: users(:ines), body: "Hmm", parent: other)
    assert_not reply.valid?
    assert_includes reply.errors[:parent], "must be in the same conversation"
  end

  test "topic messages follow the same rules" do
    topic = topics(:refresh_tokens)
    first = topic.messages.create!(author: users(:jonas), body: "Repro'd")
    assert topic.messages.build(author: users(:ines), body: "On it", parent: first).valid?

    other = projects(:apollo).topics.create!(author: users(:ines), title: "Another topic")
    assert_not other.messages.build(author: users(:ines), body: "Cross-thread", parent: first).valid?
  end

  test "only the author can edit, and editing stamps edited_at" do
    assert @first.editable_by?(users(:jonas))
    assert_not @first.editable_by?(users(:ines))

    @first.edit!("Counters are merged and deployed.")
    assert @first.edited?
    assert_equal "Counters are merged and deployed.", @first.reload.body
  end

  test "editing to an empty body is invalid" do
    assert_raises(ActiveRecord::RecordInvalid) { @first.edit!("  ") }
  end

  test "authors and project admins can remove, other members cannot" do
    assert @first.removable_by?(users(:jonas), @project)
    assert @first.removable_by?(users(:ines), @project) # superadmin
    stranger = User.create!(name: "Stranger", email: "s@x.io")
    assert_not @first.removable_by?(stranger, @project)
  end

  test "removal is soft: the row stays, the text goes and replies keep their quote" do
    reply = @task.messages.create!(author: users(:ines), body: "Replying", parent: @first)
    @first.remove!

    assert @first.reload.deleted?
    assert_equal "", @first.body
    assert_equal "Message removed", @first.excerpt
    assert_equal @first, reply.reload.parent
    assert_not @first.editable_by?(users(:jonas))
    assert_not @first.edited?
  end

  test "excerpts are single-line and trimmed" do
    message = @task.messages.create!(author: users(:ines), body: "line one\nline   two " + "x" * 200)
    assert_not_includes message.excerpt, "\n"
    assert_operator message.excerpt.length, :<=, 90
  end

  test "destroying a message detaches its replies instead of failing" do
    reply = @task.messages.create!(author: users(:ines), body: "Replying", parent: @first)
    @first.destroy!
    assert_nil reply.reload.parent
  end
end
