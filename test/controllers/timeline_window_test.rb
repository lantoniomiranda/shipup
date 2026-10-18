require "test_helper"

class TimelineWindowTest < ActiveSupport::TestCase
  setup { @project = projects(:apollo) }

  test "the window opens on the week containing today" do
    timeline = Timeline.new(project: @project, today: Date.new(2026, 12, 23))
    assert_equal Date.new(2026, 12, 21), timeline.from
    assert timeline.current_window?
    assert_not Timeline.new(project: @project, from: Date.new(2026, 1, 5), today: Date.new(2026, 12, 23)).current_window?
  end

  test "bars never start or end on a weekend" do
    Timeline.new(project: @project, today: Date.new(2026, 10, 17)).rows.flat_map(&:bars).each do |bar|
      assert bar.starts_on.on_weekday?, "#{bar.title} starts #{bar.starts_on}"
      assert bar.ends_on.on_weekday?, "#{bar.title} ends #{bar.ends_on}"
    end
  end

  test "tasks without an estimate take one working day and features outside the window are left out" do
    tasks(:rate_limiting).update!(estimate_minutes: nil)
    bar = Timeline.new(project: @project).rows.find { |row| row.title == "Per-key rate limiting" }.bars.first
    assert_equal bar.starts_on, bar.ends_on

    far = Timeline.new(project: @project, from: Date.new(2030, 1, 7))
    assert_empty far.rows
    assert far.scheduled_tasks?
  end

  test "extra features are counted instead of silently dropped" do
    (Timeline::MAX_ROWS + 2).times do |index|
      @project.tasks.create!(title: "Extra #{index}", creator: users(:ines), sprint: sprints(:sprint_14), estimate_days: 1)
    end
    timeline = Timeline.new(project: @project)
    assert_equal Timeline::MAX_ROWS, timeline.rows.size
    assert_operator timeline.hidden_rows, :>, 0
  end

  test "a project without scheduled tasks has no rows" do
    @project.tasks.update_all(sprint_id: nil)
    assert_not Timeline.new(project: @project).scheduled_tasks?
    assert_empty Timeline.new(project: @project).rows
  end
end

class TimelineEdgeTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    sign_in_as users(:ines)
  end

  test "renders the empty state without scheduled tasks" do
    @project.tasks.update_all(sprint_id: nil)
    get project_timeline_path(@project)
    assert_response :success
    assert_select ".gantt__empty"
  end

  test "ignores a malformed or absurd from date" do
    get project_timeline_path(@project, from: "nonsense")
    assert_response :success
    get project_timeline_path(@project, from: "9999-01-01")
    assert_response :success
    assert_select ".gantt__today"
  end

  test "bars link to their task" do
    get project_timeline_path(@project)
    assert_select "a.gantt__bar[href=?]", project_task_path(@project, tasks(:rate_limiting))
  end
end
