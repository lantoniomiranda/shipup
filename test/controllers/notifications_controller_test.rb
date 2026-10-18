require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @topic = topics(:refresh_tokens)
    @message = @topic.messages.create!(author: users(:ines), body: "Question")
    @reply = @topic.messages.create!(author: users(:jonas), body: "Answer", parent: @message)
    sign_in_as users(:ines)
  end

  test "the bell links to the inbox, shows a dot when there is something unread, and has a shortcut" do
    get root_path
    assert_select "a.icon-button[data-hotkey='g n'][href=?]", notifications_path
    assert_select "a[data-hotkey='g n'] .icon-button__dot"
  end

  test "no dot once everything is read" do
    Notification.mark_all_read(users(:ines))
    get root_path
    assert_select "a[data-hotkey='g n'] .icon-button__dot", count: 0
  end

  test "the inbox lists notifications with their sentence, newest first, unread highlighted" do
    Notification.notify(user: users(:ines), kind: :task_assigned, subject: tasks(:rate_limiting), actor: users(:jonas))
    get notifications_path

    assert_response :success
    assert_select ".notification", 2
    assert_select ".notification:first-child .notification__text strong", /Jonas K\. assigned you APO-97/
    assert_select ".notification--unread", 2
    assert_select ".notification__text strong", /replied to you in “Refresh tokens expire silently after 24h”/
  end

  test "opening one marks it read and goes to the message" do
    note = users(:ines).notifications.sole
    get notification_path(note)

    assert_redirected_to project_topic_path(@project, @topic, anchor: "message-#{@reply.id}")
    assert note.reload.read?
  end

  test "task notifications open the task" do
    Notification.notify(user: users(:ines), kind: :task_assigned, subject: tasks(:rate_limiting), actor: users(:jonas))
    note = users(:ines).notifications.find_by!(kind: "task_assigned")
    get notification_path(note)
    assert_redirected_to project_task_path(@project, tasks(:rate_limiting))
  end

  test "mark all read" do
    post read_all_notifications_path
    assert_redirected_to notifications_path
    assert_empty users(:ines).notifications.unread
  end

  test "you only ever see your own notifications" do
    theirs = Notification.notify(user: users(:jonas), kind: :task_assigned, subject: tasks(:rate_limiting), actor: users(:ines))
    get notification_path(theirs)
    assert_response :not_found
    assert_not theirs.reload.read?
    get notifications_path
    assert_select ".notification", 1
  end

  test "an empty inbox explains what will appear" do
    users(:ines).notifications.destroy_all
    get notifications_path
    assert_select ".empty", /Replies, @mentions/
  end

  test "a notification whose record was deleted falls back to the inbox" do
    note = users(:ines).notifications.sole
    @reply.destroy!
    get notification_path(note.reload)
    assert_redirected_to notifications_path
  end
end
