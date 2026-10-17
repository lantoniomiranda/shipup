require "test_helper"

class SprintsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    sign_in_as users(:ines) # workspace admin
  end

  test "the form proposes the next sprint" do
    get new_project_sprint_path(@project)
    assert_response :success
    assert_select "h1", /sprint 15/i
    assert_select "input[type=checkbox][name=start_now][checked]"
    assert_select "input[type=checkbox][name=carry_over][checked]" # there is an active sprint to carry from
  end

  test "creating and starting a sprint puts it on the board and completes the old one" do
    assert_difference "@project.sprints.count", 1 do
      post project_sprints_path(@project), params: { sprint: { goal: "Ship rate limits", starts_on: Date.current, ends_on: Date.current + 13 }, start_now: "1", carry_over: "1" }
    end

    sprint = @project.sprints.order(:number).last
    assert_redirected_to project_board_path(@project)
    assert_equal 15, sprint.number
    assert sprint.active?
    assert sprints(:sprint_14).reload.completed?
    assert_equal sprint, tasks(:rate_limiting).reload.sprint

    get project_board_path(@project)
    assert_select ".toolbar h1", /#{sprint.starts_on.strftime("%b %-d")}/
    assert_select ".column[data-status=in_progress] .card__title", "Per-key rate limiting"
  end

  test "a sprint can be planned without starting it" do
    post project_sprints_path(@project), params: { sprint: { starts_on: Date.current + 14, ends_on: Date.current + 27 }, start_now: "0" }

    sprint = @project.sprints.order(:number).last
    assert_redirected_to project_backlog_path(@project)
    assert sprint.planned?
    assert sprints(:sprint_14).reload.active?
  end

  test "ends before starts is rejected" do
    assert_no_difference "Sprint.count" do
      post project_sprints_path(@project), params: { sprint: { starts_on: Date.current + 5, ends_on: Date.current }, start_now: "0" }
    end
    assert_response :unprocessable_content
  end

  test "starting a planned sprint from the backlog" do
    planned = @project.sprints.create!(number: 15, starts_on: Date.current + 3, ends_on: Date.current + 16)
    patch start_project_sprint_path(@project, planned)

    assert_redirected_to project_board_path(@project)
    assert planned.reload.active?
  end

  test "only planned sprints can be started" do
    patch start_project_sprint_path(@project, sprints(:sprint_14))
    assert_match(/can't be started/, flash[:alert])
  end

  test "completing the active sprint moves unfinished work to the next planned one" do
    planned = @project.sprints.create!(number: 15, starts_on: Date.current + 3, ends_on: Date.current + 16)
    patch complete_project_sprint_path(@project, sprints(:sprint_14))

    assert sprints(:sprint_14).reload.completed?
    assert_equal planned, tasks(:rate_limiting).reload.sprint
    assert_nil @project.active_sprint
  end

  test "the board explains when no sprint is active and offers to start one" do
    sprints(:sprint_14).complete!
    get project_board_path(@project)
    assert_select ".toolbar h1", "No active sprint"
    assert_select "a", /Start a sprint/
  end

  test "members who do not manage the project cannot manage sprints" do
    sign_out
    sign_in_as users(:jonas)
    get new_project_sprint_path(@project)
    assert_response :forbidden
    assert_no_difference "Sprint.count" do
      post project_sprints_path(@project), params: { sprint: { starts_on: Date.current, ends_on: Date.current + 13 } }
    end
  end

  test "a project manager who is not a workspace admin can" do
    sign_out
    ProjectMembership.create!(project: @project, user: users(:jonas), role: "manager")
    sign_in_as users(:jonas)
    get new_project_sprint_path(@project)
    assert_response :success
  end

  test "the backlog links to the form and offers Start sprint for the planned one" do
    @project.sprints.create!(number: 15, starts_on: Date.current + 3, ends_on: Date.current + 16)
    get project_backlog_path(@project)
    assert_select "a[href=?]", new_project_sprint_path(@project)
    assert_select "button", /Start sprint/
  end
end
