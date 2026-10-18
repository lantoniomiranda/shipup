require "test_helper"

class BacklogTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @next_sprint = @project.sprints.create!(number: 15, starts_on: Date.current + 3, ends_on: Date.current + 16)
    @planned = @project.tasks.create!(title: "Fix expiry", creator: users(:ines), assignee: users(:jonas), sprint: @next_sprint, estimate_days: 3, topic: topics(:refresh_tokens))
    @loose = @project.tasks.create!(title: "Audit export", creator: users(:ines))
    sign_in_as users(:ines)
  end

  test "shows the next sprint and the backlog with capacity" do
    get project_backlog_path(@project)

    assert_response :success
    assert_select ".table__group strong", "Sprint 15"
    assert_select ".table__group strong", "Backlog"
    assert_select ".table__title", "Fix expiry"
    assert_select ".table__title", "Audit export"
    assert_select ".capacity strong", "3"
    assert_select ".capacity span", /20 XP planned/ # two members x 10 days
    assert_select ".load li", 2
    assert_select ".tab--active", /Backlog/
  end

  test "model reports capacity and load" do
    backlog = Backlog.new(project: @project)
    assert_equal @next_sprint, backlog.sprint
    assert_equal 3, backlog.planned_days
    assert_equal 17, backlog.free_days
    assert_equal [ [ users(:jonas), 3 ], [ users(:ines), 0 ] ], backlog.load_by_person
    assert_equal({ "all" => 2, "chains" => 0, "unassigned" => 1, "unestimated" => 1 }, backlog.counts)
  end

  test "filters narrow both lists" do
    get project_backlog_path(@project, filter: "unassigned")
    assert_select ".table__title", "Audit export"
    assert_select ".table__title", text: "Fix expiry", count: 0
  end

  test "moving a task into the sprint and back" do
    patch schedule_project_task_path(@project, @loose, to: "sprint")
    assert_equal @next_sprint, @loose.reload.sprint

    patch schedule_project_task_path(@project, @loose, to: "backlog")
    assert_nil @loose.reload.sprint
  end

  test "cannot schedule into a sprint that does not exist" do
    @next_sprint.destroy
    patch schedule_project_task_path(@project, @loose, to: "sprint")
    assert_match(/Plan a sprint first/, flash[:alert])
  end
end
