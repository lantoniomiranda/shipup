require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup { @project = projects(:apollo) }

  test "assigns the next project number and exposes a key" do
    @project.update!(last_task_number: 130)
    task = @project.tasks.create!(title: "Fix expiry", creator: users(:ines))
    assert_equal 131, task.number
    assert_equal "APO-131", task.key
  end

  test "stamps completed_at when moved to done and clears it when reopened" do
    task = tasks(:rate_limiting)
    task.update!(status: "done")
    assert_not_nil task.completed_at
    task.update!(status: "testing")
    assert_nil task.completed_at
  end

  test "rejects an unknown status" do
    assert_not tasks(:rate_limiting).tap { |t| t.status = "nope" }.valid?
  end

  test "is overdue only while unfinished" do
    task = tasks(:rate_limiting)
    task.due_on = Date.current - 1
    assert task.overdue?
    task.status = "done"
    assert_not task.overdue?
  end

  test "sums logged minutes including a running timer" do
    task = tasks(:rate_limiting)
    task.time_entries.create!(user: users(:jonas), started_at: 2.hours.ago, ended_at: 1.hour.ago)
    assert_equal 60, task.logged_minutes
  end

  test "walks to the next step of a chain" do
    chain = @project.chains.create!(title: "Fix expiry")
    backend = @project.tasks.create!(title: "Backend", creator: users(:ines), chain: chain, chain_position: 1)
    dashboard = @project.tasks.create!(title: "Dashboard", creator: users(:ines), chain: chain, chain_position: 2)
    assert_equal dashboard, backend.next_in_chain
    assert_nil dashboard.next_in_chain
  end

  test "chain steps need a position" do
    chain = @project.chains.create!(title: "Chain")
    assert_not @project.tasks.build(title: "Step", creator: users(:ines), chain: chain).valid?
  end
end
