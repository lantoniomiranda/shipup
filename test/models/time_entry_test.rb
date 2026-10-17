require "test_helper"

class TimeEntryTest < ActiveSupport::TestCase
  test "a user can only have one running timer" do
    tasks(:rate_limiting).time_entries.create!(user: users(:jonas), started_at: 1.hour.ago)
    assert_raises(ActiveRecord::RecordNotUnique) do
      tasks(:spec_published).time_entries.create!(user: users(:jonas), started_at: Time.current)
    end
  end

  test "stopping a timer records its length" do
    entry = tasks(:rate_limiting).time_entries.create!(user: users(:jonas), started_at: 90.seconds.ago)
    assert entry.running?
    entry.stop!
    assert_not entry.running?
    assert_in_delta 90, entry.seconds, 2
  end

  test "cannot end before it started" do
    entry = TimeEntry.new(task: tasks(:rate_limiting), user: users(:jonas), started_at: Time.current, ended_at: 1.hour.ago)
    assert_not entry.valid?
  end
end
