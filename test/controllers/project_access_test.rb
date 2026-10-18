require "test_helper"

# People only reach the projects they were invited to (admins reach all of them), whatever route they try.
class ProjectAccessTest < ActionDispatch::IntegrationTest
  setup do
    @secret = Project.create!(name: "Secret Project", key: "SEC")
    @secret_sprint = @secret.sprints.create!(number: 1, starts_on: Date.current, ends_on: Date.current + 13, state: "active")
    @secret_topic = @secret.topics.create!(author: users(:ines), title: "Hidden topic")
    @secret_task = @secret.tasks.create!(title: "Hidden task", creator: users(:ines), sprint: @secret_sprint)
    sign_in_as users(:jonas) # a plain member of Apollo only
  end

  test "pages never list a project the user is not on" do
    [ root_path, project_topics_path(projects(:apollo)), project_board_path(projects(:apollo)), project_backlog_path(projects(:apollo)),
      project_clients_path(projects(:apollo)), project_members_path(projects(:apollo)), time_off_requests_path ].each do |path|
      get path
      assert_response :success, path
      assert_not_includes response.body, "Secret Project", "#{path} leaked a project"
    end
  end

  test "an uninvited project is a 404 on every project route" do
    [ project_path(@secret), project_topics_path(@secret), new_project_topic_path(@secret), project_board_path(@secret),
      project_backlog_path(@secret), project_timeline_path(@secret), project_analytics_path(@secret), project_clients_path(@secret),
      project_members_path(@secret), new_project_sprint_path(@secret), project_topic_path(@secret, @secret_topic),
      project_task_path(@secret, @secret_task.number) ].each do |path|
      get path
      assert_response :not_found, path
    end
  end

  test "topics and tasks of another project cannot be opened through a visible one" do
    get project_topic_path(projects(:apollo), @secret_topic)
    assert_response :not_found
    get project_task_path(projects(:apollo), @secret_task.number)
    assert_response :not_found
  end

  test "writes against an uninvited project are refused" do
    assert_no_difference [ "TopicMessage.count", "TaskMessage.count", "TopicVote.count", "TimeEntry.count", "Invitation.count" ] do
      post project_topic_messages_path(@secret, @secret_topic), params: { message: { body: "hi" } }
      post project_task_messages_path(@secret, @secret_task), params: { message: { body: "hi" } }
      post project_topic_vote_path(@secret, @secret_topic, value: 1)
      post project_task_timer_path(@secret, @secret_task)
      post project_invitations_path(@secret), params: { invitation: { email: "x@y.io", role: "member" } }
    end
    patch project_task_path(@secret, @secret_task), params: { task: { status: "done" } }
    assert_response :not_found
    assert_equal "todo", @secret_task.reload.status
  end

  test "search stays inside the user's projects" do
    get search_path(q: "hidden")
    assert_select ".spotlight__result", count: 0
  end

  test "admins can open every project" do
    sign_out
    sign_in_as users(:ines)
    get project_topics_path(@secret)
    assert_response :success
  end

  test "only admins reach integrations and the new project form" do
    [ integrations_path, new_project_path, github_repositories_path ].each do |path|
      get path
      assert_response :forbidden, path
    end
    assert_no_difference "Project.count" do
      post projects_path, params: { project: { name: "Nope", key: "NOP" } }
    end
    assert_response :forbidden
  end

  test "the old multi-tenant and backoffice routes are gone" do
    sign_out
    sign_in_as users(:ines)
    get "/backoffice"
    assert_response :not_found
    get "/people"
    assert_response :not_found
  end

  test "a signed-in person with no project sees how to get access" do
    sign_out
    lonely = User.create!(name: "Lone Ly", email: "lonely@elsewhere.io")
    Invitation.create!(project: projects(:apollo), email: lonely.email).revoke!
    sign_in_as lonely
    get root_path
    assert_response :success
    assert_select ".empty", /not on a project yet/
  end
end
