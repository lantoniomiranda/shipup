require "test_helper"

class MeetingSlotsTest < ActiveSupport::TestCase
  FRIDAY = Time.utc(2026, 10, 16, 9)

  test "suggests one slot per upcoming working day and skips weekends" do
    slots = MeetingSlots.suggest([ users(:ines) ], from: FRIDAY, days: 3)
    assert_equal [ Date.new(2026, 10, 19), Date.new(2026, 10, 20), Date.new(2026, 10, 21) ], slots.map { |slot| slot.starts_at.to_date }
  end

  test "picks an hour inside everyone's working hours when one exists" do
    # Lisbon (UTC+1 in Oct = 09:00-17:00 local) and Berlin (UTC+2) overlap 08:00-15:00 UTC.
    slot = MeetingSlots.suggest([ users(:ines), users(:jonas) ], from: FRIDAY, days: 1).first
    assert_equal 2, slot.covered
    assert_equal 2, slot.total
    assert_includes 8..14, slot.starts_at.hour
  end

  test "falls back to the best partial overlap when the day cannot cover everyone" do
    tokyo = User.create!(name: "Tokyo", email: "t@x.io", time_zone: "Asia/Tokyo")
    slot = MeetingSlots.suggest([ users(:ines), tokyo ], from: FRIDAY, days: 1).first
    assert_equal 1, slot.covered
    assert_equal 2, slot.total
  end

  test "labels the slot with date, UTC time and length" do
    slot = MeetingSlots::Slot.new(starts_at: Time.utc(2026, 10, 22, 14), covered: 3, total: 4)
    assert_equal "Thu 22 Oct · 14:00 UTC · 30 min", slot.label(30)
  end
end
