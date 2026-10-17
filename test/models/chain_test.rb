require "test_helper"

class ChainTest < ActiveSupport::TestCase
  setup { @project = projects(:apollo) }

  test "create_with_steps! numbers steps and skips blank ones" do
    chain = Chain.create_with_steps!(project: @project, creator: users(:ines), title: "Ship it", steps: [
      { title: "One", estimate_days: "1" }, { title: " " }, { title: "Two", estimate_days: "0.5" }
    ])

    assert_equal [ [ "One", 1, 480 ], [ "Two", 2, 240 ] ], chain.tasks.map { |t| [ t.title, t.chain_position, t.estimate_minutes ] }
    assert_equal 720, chain.total_estimate_minutes
  end

  test "create_with_steps! is all-or-nothing" do
    assert_no_difference [ "Chain.count", "Task.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        Chain.create_with_steps!(project: @project, creator: users(:ines), title: "Broken", steps: [ { title: "Fine" }, { title: "Bad", estimate_days: "-1" } ])
      end
    end
  end

  test "an empty chain is invalid" do
    assert_raises(ActiveRecord::RecordInvalid) { Chain.create_with_steps!(project: @project, creator: users(:ines), title: "None", steps: []) }
  end
end

class TaskEstimateTest < ActiveSupport::TestCase
  test "estimates are entered in working days and stored in minutes" do
    task = projects(:apollo).tasks.new(title: "T", creator: users(:ines), estimate_days: "2.5")
    assert_equal 1200, task.estimate_minutes
    assert_equal 2.5, task.estimate_days
    task.estimate_days = ""
    assert_nil task.estimate_minutes
  end
end
