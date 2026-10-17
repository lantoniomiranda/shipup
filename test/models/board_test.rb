require "test_helper"

class BoardTest < ActiveSupport::TestCase
  setup do
    @project = projects(:apollo)
    @board = Board.new(project: @project)
  end

  test "groups the sprint's tasks into columns in board order" do
    assert_equal Task::STATUSES, @board.columns.map(&:status)
    assert_equal [ "Per-key rate limiting" ], @board.columns.find { |c| c.status == "in_progress" }.tasks.map(&:title)
    assert_equal [ "OpenAPI spec published" ], @board.columns.find { |c| c.status == "done" }.tasks.map(&:title)
  end

  test "reports XP as estimated hours done over total" do
    assert_equal 15, @board.total_points # 600 + 300 minutes
    assert_equal 5, @board.done_points
    assert_equal 33, @board.progress_percent
  end

  test "tasks outside the sprint are not on the board" do
    @project.tasks.create!(title: "Backlog item", creator: users(:ines))
    assert_not_includes @board.columns.flat_map { |c| c.tasks.map(&:title) }, "Backlog item"
  end

  test "hides chain steps until the earlier ones are done" do
    chain = Chain.create_with_steps!(project: @project, creator: users(:ines), sprint: sprints(:sprint_14), title: "Ship", steps: [ { title: "First" }, { title: "Second" } ])
    titles = -> { Board.new(project: @project).columns.flat_map { |c| c.tasks.map(&:title) } }

    assert_includes titles.call, "First"
    assert_not_includes titles.call, "Second"

    chain.tasks.first.move_to!("done")
    assert_includes titles.call, "Second"
  end

  test "without a sprint the board is empty" do
    board = Board.new(project: @project, sprint: nil)
    assert board.columns.all? { |c| c.tasks.empty? }
    assert_equal 0, board.progress_percent
  end

  test "tasks know their logged time without extra queries" do
    task = tasks(:rate_limiting)
    task.time_entries.create!(user: users(:jonas), started_at: 3.hours.ago, ended_at: 2.hours.ago)
    loaded = @project.tasks.with_logged_minutes.find(task.id)
    assert_equal 60, loaded.logged_minutes
    assert_not loaded.over_estimate?
  end
end

class TaskWorkflowTest < ActiveSupport::TestCase
  test "advancing walks the board order" do
    assert_equal "testing", tasks(:rate_limiting).next_status
    assert_nil tasks(:spec_published).next_status
  end

  test "a chain step is locked until the previous one is done" do
    chain = Chain.create_with_steps!(project: projects(:apollo), creator: users(:ines), title: "C", steps: [ { title: "A" }, { title: "B" } ])
    first, second = chain.tasks.to_a
    assert_not first.locked?
    assert second.locked?
    first.move_to!("done")
    assert_not second.reload.locked?
  end

  test "over-estimate is detected" do
    task = tasks(:rate_limiting)
    task.time_entries.create!(user: users(:jonas), started_at: 12.hours.ago, ended_at: 1.hour.ago)
    assert task.over_estimate?
  end
end
