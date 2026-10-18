require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "upcases the key and validates its shape" do
    project = Project.new(name: "Atlas", key: " atl ")
    assert project.valid?
    assert_equal "ATL", project.key
    assert_not Project.new(name: "X", key: "A1").valid?
  end

  test "keys are unique" do
    assert_not Project.new(name: "Dup", key: "APO").valid?
  end

  test "hands out sequential task numbers" do
    project = projects(:apollo)
    first = project.next_task_number!
    assert_equal first + 1, project.next_task_number!
  end

  test "the active sprint is the one on the board" do
    assert_equal sprints(:sprint_14), projects(:apollo).active_sprint
  end
end
