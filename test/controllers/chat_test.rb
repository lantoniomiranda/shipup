require "test_helper"

class ChatTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @task = tasks(:rate_limiting)
    @topic = topics(:refresh_tokens)
    sign_in_as users(:jonas)
  end

  def post_task_message(body, parent: nil)
    post project_task_messages_path(@project, @task), params: { message: { body: body, parent_id: parent&.id } }
  end

  test "the task page shows the chat with a composer" do
    @task.messages.create!(author: users(:ines), body: "Northwind needs this before the Oct 26 launch.")
    get project_task_path(@project, @task)

    assert_select ".chat header h3", "Chat"
    assert_select ".chat .message", 1
    assert_select ".chat .message__text", /Northwind needs this/
    assert_select ".chat form.composer textarea[name='message[body]']"
  end

  test "posting a message adds it to the task chat" do
    assert_difference "@task.messages.count", 1 do
      post_task_message("Counters are merged.")
    end
    assert_redirected_to project_task_path(@project, @task, anchor: "message-#{@task.messages.last.id}")
    assert_equal users(:jonas), @task.messages.last.author
  end

  test "an empty message is refused" do
    assert_no_difference "TaskMessage.count" do
      post_task_message("   ")
    end
    assert_match(/Write something/, flash[:alert])
  end

  test "a direct reply stores the quoted message and renders the quote" do
    original = @task.messages.create!(author: users(:ines), body: "Can you size both?")
    post_task_message("Backend 3d, banner 1d.", parent: original)

    reply = @task.messages.order(:id).last
    assert_equal original, reply.parent

    get project_task_path(@project, @task)
    assert_select "#message-#{reply.id} .message__quote", /Inês M\..*Can you size both\?/m
    assert_select "#message-#{reply.id} .message__quote[href='#message-#{original.id}']"
  end

  test "replying to a message from another task quietly posts a plain message" do
    foreign = tasks(:spec_published).messages.create!(author: users(:ines), body: "Different task")
    post_task_message("Hi", parent: foreign)
    assert_nil @task.messages.last.parent
  end

  test "authors can edit their message; it shows as edited" do
    message = @task.messages.create!(author: users(:jonas), body: "Orginal")
    patch project_task_message_path(@project, @task, message), params: { message: { body: "Original" } }

    assert_equal "Original", message.reload.body
    assert message.edited?
    get project_task_path(@project, @task)
    assert_select "#message-#{message.id} .message__edited", "edited"
  end

  test "nobody else can edit someone's message" do
    message = @task.messages.create!(author: users(:ines), body: "Mine")
    patch project_task_message_path(@project, @task, message), params: { message: { body: "Hijacked" } }
    assert_response :forbidden
    assert_equal "Mine", message.reload.body
  end

  test "editing to nothing is refused with a hint to remove instead" do
    message = @task.messages.create!(author: users(:jonas), body: "Keep")
    patch project_task_message_path(@project, @task, message), params: { message: { body: "" } }
    assert_match(/can't be empty/, flash[:alert])
    assert_equal "Keep", message.reload.body
  end

  test "authors can remove their message and the thread shows a placeholder" do
    message = @task.messages.create!(author: users(:jonas), body: "Oops")
    delete project_task_message_path(@project, @task, message)

    assert message.reload.deleted?
    get project_task_path(@project, @task)
    assert_select "#message-#{message.id}.message--removed .message__text--removed", "Message removed"
    assert_select "#message-#{message.id} .message__actions", count: 0
  end

  test "a workspace admin can moderate other people's messages" do
    message = @task.messages.create!(author: users(:jonas), body: "Off topic")
    sign_out
    sign_in_as users(:ines)
    delete project_task_message_path(@project, @task, message)
    assert message.reload.deleted?
  end

  test "other members cannot remove someone else's message" do
    message = @task.messages.create!(author: users(:ines), body: "Keep me")
    delete project_task_message_path(@project, @task, message)
    assert_response :forbidden
    assert_not message.reload.deleted?
  end

  test "the action buttons follow the permissions" do
    mine = @task.messages.create!(author: users(:jonas), body: "Mine")
    theirs = @task.messages.create!(author: users(:ines), body: "Theirs")
    get project_task_path(@project, @task)

    assert_select "#message-#{mine.id} button[aria-label=Edit]"
    assert_select "#message-#{mine.id} button[aria-label=Remove]"
    assert_select "#message-#{theirs.id} button[aria-label=Edit]", count: 0
    assert_select "#message-#{theirs.id} button[aria-label=Remove]", count: 0
    assert_select "#message-#{theirs.id} button[aria-label=Reply]"
  end

  test "messages of another project's task cannot be touched" do
    other_project = workspaces(:orbit).projects.create!(name: "Other", key: "OTH")
    message = @task.messages.create!(author: users(:jonas), body: "Mine")
    delete project_task_message_path(other_project, @task, message)
    assert_response :not_found
    assert_not message.reload.deleted?
  end

  test "the topic thread supports reply, edit and remove too" do
    first = @topic.messages.create!(author: users(:ines), body: "Can you size both?")
    post project_topic_messages_path(@project, @topic), params: { message: { body: "Backend ~3d", parent_id: first.id } }
    reply = @topic.messages.order(:id).last
    assert_equal first, reply.parent

    patch project_topic_message_path(@project, @topic, reply), params: { message: { body: "Backend ~4d" } }
    assert_equal "Backend ~4d", reply.reload.body

    delete project_topic_message_path(@project, @topic, reply)
    assert reply.reload.deleted?

    get project_topic_path(@project, @topic)
    assert_select "#message-#{reply.id} .message__text--removed"
    assert_select "#topic-opening .message__actions", count: 0 # the opening text itself is not a chat message
  end

  test "a topic's reply counter still counts replies" do
    assert_difference "@topic.reload.messages_count", 1 do
      post project_topic_messages_path(@project, @topic), params: { message: { body: "Hello" } }
    end
  end
end
