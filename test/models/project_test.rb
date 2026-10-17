require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "upcases the key and validates its shape" do
    project = Project.new(workspace: workspaces(:orbit), name: "Atlas", key: " atl ")
    assert project.valid?
    assert_equal "ATL", project.key
    assert_not Project.new(workspace: workspaces(:orbit), name: "X", key: "A1").valid?
  end

  test "keys are unique per workspace" do
    assert_not Project.new(workspace: workspaces(:orbit), name: "Dup", key: "APO").valid?
  end

  test "hands out sequential task numbers" do
    project = projects(:apollo)
    first = project.next_task_number!
    assert_equal first + 1, project.next_task_number!
  end

  test "finds the sprint in flight" do
    assert_equal sprints(:sprint_14), projects(:apollo).current_sprint
  end
end
