require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @project = projects(:apollo)
    @topic = topics(:refresh_tokens)
  end

  teardown { Current.reset }

  def inbox(user) = user.notifications.recent

  test "notify respects mute settings and never notifies the actor" do
    assert Notification.notify(user: users(:ines), kind: :task_assigned, subject: tasks(:rate_limiting), actor: users(:jonas))
    assert_nil Notification.notify(user: users(:ines), kind: :task_assigned, subject: tasks(:rate_limiting), actor: users(:ines))

    users(:jonas).update_notification_subscriptions("task_assigned" => "0")
    assert_nil Notification.notify(user: users(:jonas), kind: :task_assigned, subject: tasks(:rate_limiting), actor: users(:ines))
    assert_nil Notification.notify(user: nil, kind: :task_assigned, subject: tasks(:rate_limiting))
  end

  test "defaults match the settings page: new topics are off, replies are on" do
    assert users(:ines).subscribed_to?("mention_or_reply")
    assert_not users(:ines).subscribed_to?("new_topic")
  end

  test "replying to someone's message notifies them" do
    original = @topic.messages.create!(author: users(:ines), body: "Can you size both?")
    @topic.messages.create!(author: users(:jonas), body: "Backend 3d", parent: original)

    note = inbox(users(:ines)).sole
    assert_equal "mention_or_reply", note.kind
    assert_equal users(:jonas), note.actor
    assert_not note.read?
  end

  test "replying to yourself notifies nobody" do
    original = @topic.messages.create!(author: users(:ines), body: "Note to self")
    @topic.messages.create!(author: users(:ines), body: "More", parent: original)
    assert_empty inbox(users(:ines))
  end

  test "@mentions notify the named project member once" do
    @topic.messages.create!(author: users(:jonas), body: "@Inês can you look? @inês again")
    assert_equal 1, inbox(users(:ines)).count
  end

  test "mentioning someone who also got the reply does not notify twice" do
    original = @topic.messages.create!(author: users(:ines), body: "Question")
    @topic.messages.create!(author: users(:jonas), body: "@Inês see above", parent: original)
    assert_equal 1, inbox(users(:ines)).count
  end

  test "mentions of people outside the project are ignored" do
    outsider = User.create!(name: "Olga Outsider", email: "olga@x.io")
    @topic.messages.create!(author: users(:jonas), body: "@Olga hello")
    assert_empty inbox(outsider)
  end

  test "task chat notifies the same way" do
    first = tasks(:rate_limiting).messages.create!(author: users(:ines), body: "Status?")
    tasks(:rate_limiting).messages.create!(author: users(:jonas), body: "Done", parent: first)
    assert_equal "mention_or_reply", inbox(users(:ines)).sole.kind
  end

  test "assigning a task notifies the new assignee, and only when it changes" do
    Current.session = Session.new(user: users(:ines))
    task = @project.tasks.create!(title: "Fix expiry", creator: users(:ines), assignee: users(:jonas))
    assert_equal [ "task_assigned" ], inbox(users(:jonas)).pluck(:kind)

    task.update!(title: "Fix expiry properly")
    assert_equal 1, inbox(users(:jonas)).count
    task.update!(assignee: users(:ines))
    assert_equal 1, inbox(users(:jonas)).count # reassigned away: no new one for Jonas
  end

  test "self-assignment is silent" do
    Current.session = Session.new(user: users(:ines))
    @project.tasks.create!(title: "Mine", creator: users(:ines), assignee: users(:ines))
    assert_empty inbox(users(:ines))
  end

  test "finishing a chain step unlocks the next one for its owner" do
    Current.session = Session.new(user: users(:ines))
    chain = Chain.create_with_steps!(project: @project, creator: users(:ines), title: "Ship", steps: [
      { title: "Backend", assignee_id: users(:ines).id }, { title: "Dashboard", assignee_id: users(:jonas).id }
    ])
    inbox(users(:jonas)).destroy_all # drop the assignment notice
    chain.tasks.first.move_to!("done")

    note = inbox(users(:jonas)).sole
    assert_equal "subtask_unlocked", note.kind
    assert_equal chain.tasks.last, note.subject
  end

  test "new topics notify project members who opted in, not the author" do
    users(:ines).update_notification_subscriptions("new_topic" => "1")
    topic = @project.topics.create!(author: users(:jonas), title: "Brand new")

    assert_equal [ topic ], inbox(users(:ines)).map(&:subject)
    assert_empty inbox(users(:jonas))
  end

  test "new topics are silent by default" do
    @project.topics.create!(author: users(:jonas), title: "Quiet")
    assert_empty inbox(users(:ines))
  end

  test "meeting invites notify participants but not the organizer" do
    meeting = @topic.meetings.create!(organizer: users(:ines), provider: "zoom", starts_at: 2.days.from_now)
    meeting.participants.create!(user: users(:jonas))
    meeting.participants.create!(user: users(:ines))

    assert_equal [ "meeting_invite" ], inbox(users(:jonas)).pluck(:kind)
    assert_empty inbox(users(:ines))
  end

  test "mark_all_read clears the unread count for one person" do
    Notification.notify(user: users(:ines), kind: :task_assigned, subject: tasks(:rate_limiting), actor: users(:jonas))
    Notification.notify(user: users(:jonas), kind: :task_assigned, subject: tasks(:rate_limiting), actor: users(:ines))
    Notification.mark_all_read(users(:ines))

    assert_empty users(:ines).notifications.unread
    assert_equal 1, users(:jonas).notifications.unread.count
  end
end
