require "test_helper"

class BoardAndTasksTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    sign_in_as users(:ines)
  end

  test "the board shows a column per status with its cards" do
    get project_board_path(@project)

    assert_response :success
    assert_select ".column", 5
    assert_select ".column[data-status=in_progress] .card__title", "Per-key rate limiting"
    assert_select ".column[data-status=done] .card--done"
    assert_select ".toolbar h1", /–/
    assert_select ".toolbar__points", "5/15 XP"
    assert_select ".tab--active", /Board/
  end

  test "the card being timed by the viewer is marked running" do
    tasks(:rate_limiting).time_entries.create!(user: users(:ines), started_at: 5.minutes.ago)
    get project_board_path(@project)
    assert_select ".card--running .card__timer"
  end

  test "chain steps that are still locked do not appear" do
    Chain.create_with_steps!(project: @project, creator: users(:ines), sprint: sprints(:sprint_14), title: "Ship", steps: [ { title: "First step" }, { title: "Second step" } ])
    get project_board_path(@project)
    assert_select ".card__title", text: "First step"
    assert_select ".card__title", text: "Second step", count: 0
    assert_select ".chain-strip", /Step 1 of 2/
  end

  test "a task page shows its facts and time tracker" do
    get project_task_path(@project, tasks(:rate_limiting))

    assert_response :success
    assert_select "h1", "Per-key rate limiting"
    assert_select ".facts dd", /Sprint 14/
    assert_select ".tracker__clock"
    assert_select ".pager", /of 2 in this sprint/
  end

  test "moving a card to another column records the new status" do
    patch project_task_path(@project, tasks(:rate_limiting)), params: { task: { status: "testing" } }

    assert_redirected_to project_board_path(@project)
    assert_equal "testing", tasks(:rate_limiting).reload.status
    assert_match(/APO-97 moved to Testing/, flash[:notice])
  end

  test "an unknown status is rejected" do
    patch project_task_path(@project, tasks(:rate_limiting)), params: { task: { status: "nope" } }
    assert_response :unprocessable_content
    assert_equal "in_progress", tasks(:rate_limiting).reload.status
  end

  test "completing a chain step unlocks the next one" do
    chain = Chain.create_with_steps!(project: @project, creator: users(:ines), sprint: sprints(:sprint_14), title: "Ship",
                                     steps: [ { title: "Backend" }, { title: "Dashboard" } ])
    first = chain.tasks.first
    first.update!(status: "ready_to_deploy")

    post advance_project_task_path(@project, first)

    assert first.reload.done?
    assert_match(/Dashboard is now unlocked/, flash[:notice])
  end

  test "the chain section appears on a chain task with a complete button on the current step" do
    chain = Chain.create_with_steps!(project: @project, creator: users(:ines), sprint: sprints(:sprint_14), title: "Ship",
                                     steps: [ { title: "Backend" }, { title: "Dashboard" } ])
    get project_task_path(@project, chain.tasks.first)
    assert_select ".chain-step", 2
    assert_select ".chain-step--current"
    assert_select ".chain-step--locked", /Hidden until Backend is done/
    assert_select "button", /Complete Backend, unlock Dashboard/
  end

  test "starting a timer stops any other running timer" do
    tasks(:spec_published).time_entries.create!(user: users(:ines), started_at: 1.hour.ago)

    post project_task_timer_path(@project, tasks(:rate_limiting))

    assert_equal tasks(:rate_limiting), users(:ines).running_time_entry.task
    assert_equal 1, users(:ines).time_entries.running.count
    assert_not_nil tasks(:spec_published).time_entries.first.ended_at
  end

  test "stopping a timer ends the entry" do
    tasks(:rate_limiting).time_entries.create!(user: users(:ines), started_at: 1.hour.ago)
    delete project_task_timer_path(@project, tasks(:rate_limiting))
    assert_nil users(:ines).running_time_entry
  end

  test "tasks from other projects are a 404" do
    other = Project.create!(name: "Other", key: "OTH")
    get project_task_path(other, tasks(:rate_limiting))
    assert_response :not_found
  end
end
