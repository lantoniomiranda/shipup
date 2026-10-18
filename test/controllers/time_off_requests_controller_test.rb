require "test_helper"

class TimeOffRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @month = Date.new(2026, 10, 1)
    travel_to Time.utc(2026, 10, 17, 12)
    sign_in_as users(:jonas)
    @admin = users(:ines)
  end

  teardown { travel_back }

  def request_for(user, from, to, kind: "vacation", status: "approved")
    TimeOffRequest.new(user: user, kind: kind, starts_on: from, ends_on: to, status: status).tap { |request| request.save!(validate: false) }
  end

  test "overview shows allowances, my requests and the team timeline" do
    request_for(users(:jonas), Date.new(2026, 10, 26), Date.new(2026, 10, 28), status: "pending")
    request_for(@admin, Date.new(2026, 10, 12), Date.new(2026, 10, 12), kind: "sick")
    get time_off_requests_path(month: "2026-10")

    assert_response :success
    assert_select ".allowance", 3
    assert_select ".allowance__labels span", /19 of 22 days left/ # 3 pending days count against vacation
    assert_select ".requests li", 1
    assert_select ".timeline__row", 3 # header + two people
    assert_select ".timeline__bar--waiting"
    assert_select ".timeline__bar--sick"
    assert_select ".timeline__head h2", "October 2026"
  end

  test "only approvers see the approval queue" do
    request_for(users(:jonas), Date.new(2026, 11, 3), Date.new(2026, 11, 6), status: "pending")
    get time_off_requests_path
    assert_select ".approval", count: 0

    sign_out
    sign_in_as @admin
    get time_off_requests_path
    assert_select ".approval", 1
    assert_select ".approval__who", /Jonas K\./
  end

  test "an approver can approve or decline" do
    approved = request_for(users(:jonas), Date.new(2026, 11, 3), Date.new(2026, 11, 6), status: "pending")
    declined = request_for(users(:jonas), Date.new(2026, 12, 7), Date.new(2026, 12, 8), status: "pending")
    sign_out
    sign_in_as @admin

    patch time_off_request_path(approved, decision: "approve")
    patch time_off_request_path(declined, decision: "decline")

    assert approved.reload.approved?
    assert declined.reload.declined?
    assert_equal @admin, approved.approver
  end

  test "members cannot decide requests" do
    other = request_for(@admin, Date.new(2026, 11, 3), Date.new(2026, 11, 3), status: "pending")
    patch time_off_request_path(other, decision: "approve")
    assert_response :not_found
    assert other.reload.pending?
  end

  test "the request form offers a month calendar and approvers" do
    request_for(@admin, Date.new(2026, 10, 19), Date.new(2026, 10, 20))
    get new_time_off_request_path(month: "2026-10")

    assert_response :success
    assert_select ".calendar__day[data-date]", 31
    assert_select ".calendar__away", /Away/
    assert_select "select[name=approver_id] option", /Inês M\. · superadmin/
    assert_select "input[name='time_off_request[kind]']", 3
  end

  test "sending a request stores working days and waits for the approver" do
    assert_difference "users(:jonas).time_off_requests.count", 1 do
      post time_off_requests_path, params: { time_off_request: { kind: "vacation", starts_on: "2026-10-22", ends_on: "2026-10-30" }, approver_id: @admin.id }
    end

    request = users(:jonas).time_off_requests.last
    assert_redirected_to time_off_requests_path
    assert request.pending?
    assert_equal 7, request.working_days
    assert_equal @admin, request.approver
  end

  test "a single picked day is a one-day request" do
    post time_off_requests_path, params: { time_off_request: { kind: "sick", starts_on: "2026-10-21", ends_on: "" } }
    assert_equal 1, users(:jonas).time_off_requests.last.working_days
  end

  test "requests beyond the remaining allowance are refused" do
    assert_no_difference "TimeOffRequest.count" do
      post time_off_requests_path, params: { time_off_request: { kind: "family", starts_on: "2026-10-19", ends_on: "2026-10-23" } }
    end
    assert_response :unprocessable_content
    assert_match(/3 family days/, flash[:alert])
  end

  test "an approver other than the user can be chosen only from superadmins and project admins" do
    post time_off_requests_path, params: { time_off_request: { kind: "vacation", starts_on: "2026-11-02", ends_on: "2026-11-02" }, approver_id: users(:jonas).id }
    assert_nil users(:jonas).time_off_requests.last.approver
  end
end

class TimeOffBalanceTest < ActiveSupport::TestCase
  test "balance subtracts approved and waiting days but not declined ones" do
    travel_to Time.utc(2026, 10, 17) do
      %w[approved pending declined].each_with_index do |status, index|
        TimeOffRequest.new(user: users(:ines), kind: "vacation", starts_on: Date.new(2026, 11, 2) + index * 7, ends_on: Date.new(2026, 11, 3) + index * 7, status: status).save!(validate: false)
      end
      balance = TimeOffRequest.balance_for(users(:ines), "vacation")
      assert_equal 22, balance.allowance
      assert_equal 4, balance.used
      assert_equal 18, balance.left
    end
  end

  test "a configured allowance overrides the default" do
    users(:ines).time_off_allowances.create!(kind: "vacation", year: 2026, days: 30)
    assert_equal 30, TimeOffRequest.balance_for(users(:ines), "vacation", year: 2026).allowance
  end

  test "only superadmins and project admins can approve other people's requests" do
    assert users(:ines).can_approve_time_off_for?(users(:jonas))
    assert_not users(:jonas).can_approve_time_off_for?(users(:ines))
    assert_not users(:ines).can_approve_time_off_for?(users(:ines))
  end
end
