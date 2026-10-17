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
