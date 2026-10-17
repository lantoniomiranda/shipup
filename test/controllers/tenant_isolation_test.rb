require "test_helper"

# One tenant must never see or change another's data, whatever route it tries.
class TenantIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @orbit = workspaces(:orbit)
    @apollo = projects(:apollo)

    @rival = Workspace.create!(name: "Rival Inc", email_domain: "rival.io")
    @rival_admin = User.create!(name: "Rita Rival", email: "rita@rival.io")
    @rival.memberships.create!(user: @rival_admin, role: "admin")
    @rival_project = @rival.projects.create!(name: "Rival Project", key: "RIV")
    @rival_sprint = @rival_project.sprints.create!(number: 1, starts_on: Date.current, ends_on: Date.current + 13, state: "active")
    @rival_topic = @rival_project.topics.create!(author: @rival_admin, title: "Rival secret topic")
    @rival_task = @rival_project.tasks.create!(title: "Rival secret task", creator: @rival_admin, sprint: @rival_sprint)
    @rival.clients.create!(name: "Rival Client")

    sign_in_as users(:ines) # an Orbit admin
  end

  test "Orbit's pages never list the rival's data" do
    [ root_path, project_topics_path(@apollo), project_board_path(@apollo), project_backlog_path(@apollo), project_clients_path(@apollo),
      project_timeline_path(@apollo), project_analytics_path(@apollo), memberships_path, time_off_requests_path, integrations_path ].each do |path|
      get path
      assert_response :success, path
      assert_not_includes response.body, "Rival", "#{path} leaked the rival tenant"
      assert_not_includes response.body, "rita@rival.io", "#{path} leaked a rival email"
    end
  end

  test "the rival's project is a 404 on every project route" do
    [ project_path(@rival_project), project_topics_path(@rival_project), new_project_topic_path(@rival_project), project_board_path(@rival_project),
      project_backlog_path(@rival_project), project_timeline_path(@rival_project), project_analytics_path(@rival_project),
      project_clients_path(@rival_project), new_project_sprint_path(@rival_project) ].each do |path|
      get path
      assert_response :not_found, path
    end
  end

  test "the rival's topics and tasks cannot be opened through Orbit's project" do
    get project_topic_path(@apollo, @rival_topic)
    assert_response :not_found
    get project_task_path(@apollo, @rival_task.number)
    assert_response :not_found
  end

  test "writes against the rival's records are refused" do
    assert_no_difference [ "TopicMessage.count", "TaskMessage.count", "TopicVote.count", "TimeEntry.count" ] do
      post project_topic_messages_path(@rival_project, @rival_topic), params: { message: { body: "hi" } }
      post project_task_messages_path(@rival_project, @rival_task), params: { message: { body: "hi" } }
      post project_topic_vote_path(@rival_project, @rival_topic, value: 1)
      post project_task_timer_path(@rival_project, @rival_task)
    end
    assert_not @rival_task.reload.done?
    patch project_task_path(@rival_project, @rival_task), params: { task: { status: "done" } }
    assert_response :not_found
    assert_equal "todo", @rival_task.reload.status
  end

  test "search never reaches across tenants" do
    get search_path(q: "secret")
    assert_select ".spotlight__result", count: 0
    get search_path(q: "RIV-1")
    assert_select ".spotlight__result", count: 0
  end

  test "integrations and GitHub connections are per tenant" do
    @rival.integration_connections.create!(provider: "zoom", external_account: "rival@zoom", connected_by: @rival_admin, access_token: "t")
    get integrations_path
    assert_not_includes response.body, "rival@zoom"
    assert_select ".tool__status--connected", count: 0
  end

  test "people and invitations are per tenant" do
    @rival.invitations.create!(email: "pending@rival.io")
    get memberships_path
    assert_not_includes response.body, "pending@rival.io"
    assert_not_includes response.body, "Rita Rival"
  end

  test "the rival cannot see Orbit's data either" do
    sign_out
    sign_in_as @rival_admin
    get root_path
    assert_select ".project-card h2", "Rival Project"
    assert_not_includes response.body, "Apollo Gateway"

    get project_topic_path(@apollo, topics(:refresh_tokens))
    assert_response :not_found
    get project_board_path(@apollo)
    assert_response :not_found
    get search_path(q: "refresh")
    assert_select ".spotlight__result", count: 0
  end

  test "time off requests of other tenants are invisible and cannot be decided" do
    foreign = TimeOffRequest.new(user: @rival_admin, kind: "vacation", starts_on: Date.current + 7, ends_on: Date.current + 8, status: "pending")
    foreign.save!(validate: false)
    get time_off_requests_path
    assert_select ".approval", count: 0
    patch time_off_request_path(foreign, decision: "approve")
    assert_response :not_found
    assert foreign.reload.pending?
  end

  test "the backoffice is invisible to tenant admins" do
    get backoffice_tenants_path
    assert_response :not_found
  end

  test "workspace switching only offers one's own tenants" do
    get root_path
    assert_select "button.workspaces__item", count: 0
    assert_select ".workspaces__item--current[title='Orbit Labs']"
  end
end
