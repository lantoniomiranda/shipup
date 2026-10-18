require "test_helper"

# Soft deletion and cancellation: nothing is destroyed, everything can be brought back.
class ArchivingTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @topic = topics(:refresh_tokens)
    sign_in_as users(:ines) # project admin of Apollo
  end

  # Clients

  test "archiving a client hides it everywhere and keeps its topics" do
    client = Client.create!(name: "Northwind")
    @project.project_clients.create!(client: client)
    topic = @project.topics.create!(author: users(:ines), title: "From Northwind", client: client)

    delete project_client_path(@project, client)
    assert_redirected_to project_clients_path(@project)
    assert client.reload.archived?
    assert_equal client, topic.reload.client

    get project_clients_path(@project)
    assert_select "tbody tr", count: 0
    get new_project_topic_path(@project)
    assert_select ".choice__option", text: /Northwind/, count: 0
    get project_clients_path(@project, filter: "archived")
    assert_select "tbody tr", 1
    assert_select "tbody tr", /Northwind/
  end

  test "an archived client can be restored, and onboarding it again brings it back" do
    client = Client.create!(name: "Northwind", archived_at: 1.day.ago)
    @project.project_clients.create!(client: client)

    patch restore_project_client_path(@project, client)
    assert_not client.reload.archived?

    client.archive!
    Client.onboard!(name: "Northwind", contact_name: "Priya", emails: [ "priya@northwind.io" ])
    assert_not client.reload.archived?
  end

  test "an archived client cannot be picked on a new topic" do
    client = Client.create!(name: "Gone", archived_at: 1.day.ago)
    @project.project_clients.create!(client: client)
    post project_topics_path(@project), params: { topic: { kind: "feature", title: "Hello", client_id: client.id } }
    assert_nil @project.topics.find_by!(title: "Hello").client
  end

  test "only project admins archive clients" do
    client = Client.create!(name: "Northwind")
    @project.project_clients.create!(client: client)
    sign_out
    sign_in_as users(:jonas)
    delete project_client_path(@project, client)
    assert_response :forbidden
    assert_not client.reload.archived?
  end

  # Topics

  test "the author or a project admin can cancel a topic with a reason, and reopen it" do
    sign_out
    sign_in_as users(:jonas) # author of the topic, plain member
    patch cancel_project_topic_path(@project, @topic), params: { reason: "Duplicate of ENG-4" }
    assert_redirected_to project_topic_path(@project, @topic)
    assert @topic.reload.canceled?
    assert_match(/Canceled this topic: Duplicate of ENG-4/, @topic.messages.order(:id).last.body)

    get project_topic_path(@project, @topic)
    assert_select "button", text: /Reopen topic/
    assert_select "a", text: /Create task/, count: 0

    patch reopen_project_topic_path(@project, @topic)
    assert @topic.reload.open?
  end

  test "reopening a topic that already produced work puts it back to approved" do
    @project.tasks.create!(title: "Do it", creator: users(:ines), topic: @topic)
    @topic.cancel!
    patch reopen_project_topic_path(@project, @topic)
    assert @topic.reload.approved?
  end

  test "someone who is neither the author nor a project admin cannot cancel" do
    other = User.create!(name: "Bystander", email: "by@stander.io")
    @project.project_memberships.create!(user: other)
    sign_out
    sign_in_as other
    patch cancel_project_topic_path(@project, @topic)
    assert_response :forbidden
    assert @topic.reload.open?
  end

  test "canceled topics show under the Canceled filter" do
    @topic.cancel!
    get project_topics_path(@project, filter: "canceled")
    assert_select ".topic-row__title", @topic.title
  end

  # Tasks

  test "archiving a task takes it off the board and backlog, and restoring brings it back" do
    task = tasks(:rate_limiting)
    patch archive_project_task_path(@project, task)
    assert_redirected_to project_backlog_path(@project)
    assert task.reload.archived?

    assert_not_includes @project.tasks, task
    get project_board_path(@project)
    assert_not_includes response.body, task.title
    get project_task_path(@project, task.number)
    assert_response :not_found
    get project_backlog_path(@project)
    assert_select ".archived", /1 archived task/

    patch restore_project_task_path(@project, task.number)
    assert_not task.reload.archived?
    assert_includes @project.tasks, task
  end

  test "an archived chain step does not block the steps after it" do
    chain = @project.chains.create!(title: "Ship it")
    first = @project.tasks.create!(title: "Step one", creator: users(:ines), chain: chain, chain_position: 1)
    second = @project.tasks.create!(title: "Step two", creator: users(:ines), chain: chain, chain_position: 2)
    assert_not_includes @project.tasks.unlocked, second
    first.archive!
    assert_includes @project.tasks.unlocked, second
  end

  test "only project admins archive tasks" do
    sign_out
    sign_in_as users(:jonas)
    patch archive_project_task_path(@project, tasks(:rate_limiting))
    assert_response :forbidden
    assert_not tasks(:rate_limiting).reload.archived?
  end

  # Projects

  test "a project admin completes and reopens a project" do
    patch project_path(@project), params: { project: { status: "completed" } }
    assert @project.reload.completed?
    get root_path(status: "completed")
    assert_select ".project-card h2", "Apollo Gateway"

    patch project_path(@project), params: { project: { status: "active" } }
    assert @project.reload.active?
  end

  test "members cannot complete a project and bad statuses are rejected" do
    patch project_path(@project), params: { project: { status: "bogus" } }
    assert_response :unprocessable_content
    sign_out
    sign_in_as users(:jonas)
    patch project_path(@project), params: { project: { status: "completed" } }
    assert_response :forbidden
    assert @project.reload.active?
  end
end
