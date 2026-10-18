require "test_helper"

class SprintTest < ActiveSupport::TestCase
  test "counts the days left, including today" do
    assert_equal 3, sprints(:sprint_14).days_left
    assert_equal 0, sprints(:sprint_14).days_left(from: Date.current + 30)
  end

  test "progress is the share of estimated work that is done" do
    assert_equal 33, sprints(:sprint_14).progress_percent # 300 of 900 minutes
  end

  test "cannot end before it starts" do
    sprint = sprints(:sprint_14)
    sprint.ends_on = sprint.starts_on - 1
    assert_not sprint.valid?
  end
end

class SprintLifecycleTest < ActiveSupport::TestCase
  setup do
    @project = projects(:apollo)
    @running = sprints(:sprint_14)
    @next = @project.sprints.create!(number: 15, starts_on: Date.current + 3, ends_on: Date.current + 16)
  end

  test "new sprints are planned" do
    assert @next.planned?
    assert_equal @next, @project.sprints.upcoming.first
  end

  test "starting a sprint completes the previous active one" do
    @next.start!

    assert @next.reload.active?
    assert @running.reload.completed?
    assert_not_nil @running.completed_at
    assert_equal @next, @project.active_sprint
  end

  test "unfinished tasks carry over to the new sprint, finished ones stay" do
    @next.start!

    assert_equal @next, tasks(:rate_limiting).reload.sprint
    assert_equal @running, tasks(:spec_published).reload.sprint # done
  end

  test "carry over can be switched off so unfinished tasks return to the backlog" do
    @next.start!(carry_over: false)
    assert_nil tasks(:rate_limiting).reload.sprint
  end

  test "completing a sprint moves unfinished work to the given sprint" do
    @running.complete!(carry_over_to: @next)
    assert_equal @next, tasks(:rate_limiting).reload.sprint
    assert_nil @project.reload.active_sprint
  end

  test "the database refuses a second active sprint in a project" do
    assert_raises(ActiveRecord::RecordNotUnique) { @next.update!(state: "active") }
  end

  test "other projects are unaffected" do
    other = Project.create!(name: "Other", key: "OTH")
    theirs = other.sprints.create!(number: 1, starts_on: Date.current, ends_on: Date.current + 13)
    theirs.start!
    @next.start!
    assert theirs.reload.active?
  end

  test "next_for proposes the following number and a two-week window" do
    proposal = Sprint.next_for(@project, today: Date.current)
    assert_equal 16, proposal.number
    assert_equal 13, (proposal.ends_on - proposal.starts_on).to_i
    assert_operator proposal.starts_on, :>, @next.ends_on
  end

  test "an invalid state is rejected" do
    assert_not @next.tap { |sprint| sprint.state = "paused" }.valid?
  end
end
