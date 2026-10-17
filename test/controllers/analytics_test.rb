require "test_helper"

class AnalyticsTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    travel_to Time.utc(2026, 10, 17, 12)
    sign_in_as users(:ines)
  end

  teardown { travel_back }

  def topic_on(date, status: "open")
    @project.topics.create!(author: users(:jonas), title: "T #{date}", status: status, created_at: date.to_time(:utc) + 9.hours)
  end

  test "counts topics for the period and compares with the one before" do
    topic_on(Date.new(2026, 10, 14))
    topic_on(Date.new(2026, 10, 1), status: "approved")
    topic_on(Date.new(2026, 7, 1))
    analytics = Analytics.new(project: @project, today: Date.new(2026, 10, 17))

    assert_equal 3, analytics.topics_count # includes the fixture topic created "now"
    assert_equal analytics.topics_count - 1, analytics.topics_delta
  end

  test "weeks aggregate opened, approved and canceled topics" do
    topic_on(Date.new(2026, 10, 14))
    topic_on(Date.new(2026, 10, 14), status: "canceled")
    topic_on(Date.new(2026, 10, 13), status: "approved")
    week = Analytics.new(project: @project, today: Date.new(2026, 10, 17)).weeks.last

    assert_equal "W42", week.label
    assert_operator week.opened, :>=, 3
    assert_equal 1, week.approved
    assert_equal 1, week.canceled
  end

  test "hours come from time entries on this project's tasks" do
    tasks(:rate_limiting).time_entries.create!(user: users(:jonas), started_at: Time.utc(2026, 10, 15, 9), ended_at: Time.utc(2026, 10, 15, 14))
    assert_equal 5, Analytics.new(project: @project, today: Date.new(2026, 10, 17)).hours_logged
  end

  test "meetings report minutes, decisions and average invitees" do
    decided = topic_on(Date.new(2026, 10, 10), status: "approved")
    open_topic = topic_on(Date.new(2026, 10, 11))
    [ decided, open_topic ].each_with_index do |topic, index|
      meeting = topic.meetings.create!(organizer: users(:ines), provider: "zoom", starts_at: Time.utc(2026, 10, 12 + index, 14), duration_minutes: 30)
      meeting.participants.create!(user: users(:ines))
      meeting.participants.create!(user: users(:jonas)) if index.zero?
    end
    analytics = Analytics.new(project: @project, today: Date.new(2026, 10, 17))

    assert_equal 2, analytics.meetings.size
    assert_equal 60, analytics.meeting_minutes
    assert_equal 1, analytics.decided_meetings
    assert_equal 1.5, analytics.average_invited
  end

  test "ranges fall back to the last eight weeks" do
    assert_equal "eight_weeks", Analytics.new(project: @project, range: "bogus").range_key
    assert_equal Date.new(2026, 10, 1)..Date.new(2026, 10, 17), Analytics.new(project: @project, range: "quarter", today: Date.new(2026, 10, 17)).period
  end

  test "the page renders KPIs, charts and closed topics" do
    topic_on(Date.new(2026, 10, 12), status: "approved")
    get project_analytics_path(@project)

    assert_response :success
    assert_select ".kpi", 4
    assert_select ".chart__col", 16 # eight weeks, two charts
    assert_select ".closed li", /Closed as approved/
    assert_select ".segmented__item--active", "Last 8 weeks"
    assert_select ".tab--active", /Analytics/
  end

  test "switching range highlights it" do
    get project_analytics_path(@project, range: "sprint")
    assert_select ".segmented__item--active", "This sprint"
  end
end
