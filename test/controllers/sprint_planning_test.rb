require "test_helper"

# A planned sprint must be startable and schedulable whatever its planned start date.
class SprintPlanningTest < ActionDispatch::IntegrationTest
  OFFSETS = { "today" => 0, "tomorrow" => 1, "yesterday" => -1 }.freeze

  setup do
    @project = projects(:apollo)
    sign_in_as users(:ines)
  end

  def plan(offset)
    @project.sprints.create!(number: 15, starts_on: Date.current + offset, ends_on: Date.current + offset + 13)
  end

  def todo_task(title = "Plan me")
    @project.tasks.create!(title: title, creator: users(:ines), status: "todo")
  end

  OFFSETS.each do |label, offset|
    test "a sprint planned for #{label} shows Start sprint and can be started" do
      sprint = plan(offset)
      get project_backlog_path(@project)
      assert_select "form[action=?] button", start_project_sprint_path(@project, sprint), /Start sprint/

      patch start_project_sprint_path(@project, sprint)
      assert_redirected_to project_board_path(@project)
      assert sprint.reload.active?
      assert sprints(:sprint_14).reload.completed?
    end

    test "tasks move into a sprint planned for #{label} and show on the backlog" do
      sprint = plan(offset)
      task = todo_task
      patch schedule_project_task_path(@project, task, to: "sprint")
      assert_equal sprint, task.reload.sprint

      get project_backlog_path(@project)
      assert_select "tr", text: /Plan me/ do |rows|
        assert_equal 1, rows.size
      end
      assert_select "tr.table__group", text: /Sprint 15/
    end

    test "a chain scheduled into a sprint planned for #{label} moves as a whole" do
      sprint = plan(offset)
      chain = Chain.create_with_steps!(project: @project, creator: users(:ines), title: "Chained", sprint: sprint,
                                       steps: [ { title: "Step one" }, { title: "Step two" } ])
      get project_backlog_path(@project)
      assert_select "tr", text: /Step one/
      assert_select "tr", text: /Step two/ # locked steps are listed too

      patch schedule_project_task_path(@project, chain.tasks.first, to: "backlog")
      assert_equal [ nil, nil ], chain.tasks.reload.map(&:sprint_id)
      patch schedule_project_task_path(@project, chain.tasks.first, to: "sprint")
      assert_equal [ sprint.id, sprint.id ], chain.tasks.reload.map(&:sprint_id)
    end
  end

  test "with several planned sprints a task can go to a chosen one" do
    plan(0)
    later = @project.sprints.create!(number: 16, starts_on: Date.current + 14, ends_on: Date.current + 27)
    task = todo_task
    patch schedule_project_task_path(@project, task, to: "sprint", sprint_id: later.id)
    assert_equal later, task.reload.sprint
    get project_backlog_path(@project)
    assert_select "tr.table__group", text: /Sprint 16/
    assert_select "form[action=?] button", start_project_sprint_path(@project, later), /Start sprint/
  end

  test "pickers offer planned and active sprints but not completed ones" do
    planned = plan(0)
    done = @project.sprints.create!(number: 3, starts_on: Date.current - 90, ends_on: Date.current - 77, state: "completed")
    topic = topics(:one) rescue @project.topics.first
    get new_project_topic_chain_path(@project, topic)
    assert_select "select[name='chain[sprint_id]'] option[value=?]", planned.id.to_s
    assert_select "select[name='chain[sprint_id]'] option[value=?]", done.id.to_s, count: 0
  end

  test "the board with no active sprint offers to start the planned one" do
    sprints(:sprint_14).complete!
    sprint = plan(0)
    get project_board_path(@project)
    assert_select "form[action=?] button", start_project_sprint_path(@project, sprint), /Start sprint/
  end

  test "an unscheduled task can join the running sprint and shows on the board" do
    task = todo_task("Join running")
    get project_backlog_path(@project)
    assert_select "tr.table__group", text: /Sprint 14.*in progress/m
    assert_select "form[action=?] button", schedule_project_task_path(@project, task, to: "sprint", sprint_id: sprints(:sprint_14).id)

    patch schedule_project_task_path(@project, task, to: "sprint", sprint_id: sprints(:sprint_14).id)
    assert_equal sprints(:sprint_14), task.reload.sprint
    get project_backlog_path(@project)
    assert_select "tr", text: /Join running/ # listed under the running sprint
    get project_board_path(@project)
    assert_select "article.card", text: /Join running/
  end

  test "a task cannot be scheduled into a completed sprint" do
    done = @project.sprints.create!(number: 3, starts_on: Date.current - 90, ends_on: Date.current - 77, state: "completed")
    task = todo_task
    patch schedule_project_task_path(@project, task, to: "sprint", sprint_id: done.id)
    assert_nil task.reload.sprint
  end

  test "a failed sprint form keeps the start now and carry over choices" do
    post project_sprints_path(@project), params: { sprint: { goal: "G", starts_on: Date.current, ends_on: Date.current - 1 }, start_now: "0", carry_over: "0" }
    assert_response :unprocessable_content
    assert_select "input#start_now[checked]", count: 0
    assert_select "input#carry_over[checked]", count: 0
    assert_select "input#sprint_goal[value=?]", "G"
  end
end
