require "test_helper"

class TimeOffRequestTest < ActiveSupport::TestCase
  test "counts only working days" do
    request = users(:ines).time_off_requests.create!(kind: "vacation", starts_on: Date.new(2026, 10, 22), ends_on: Date.new(2026, 10, 30))
    assert_equal 7, request.working_days
  end

  test "deciding records who approved and when" do
    request = users(:jonas).time_off_requests.create!(kind: "sick", starts_on: Date.new(2026, 10, 12), ends_on: Date.new(2026, 10, 12))
    request.decide!(by: users(:ines), approve: true)
    assert request.approved?
    assert_equal users(:ines), request.approver
    assert_not_nil request.decided_at
  end

  test "finds requests overlapping a range" do
    request = users(:jonas).time_off_requests.create!(kind: "vacation", starts_on: Date.new(2026, 11, 3), ends_on: Date.new(2026, 11, 7))
    assert_includes TimeOffRequest.overlapping(Date.new(2026, 11, 4)..Date.new(2026, 11, 4)), request
  end
end
