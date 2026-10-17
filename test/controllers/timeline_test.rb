require "test_helper"

class TimelineTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    sign_in_as users(:ines)
  end

  test "schedules a feature's tasks back to back as bars" do
    chain = Chain.create_with_steps!(project: @project, creator: users(:ines), topic: topics(:refresh_tokens), sprint: sprints(:sprint_14), title: "Fix", steps: [
      { title: "Backend", estimate_days: 3 }, { title: "Dashboard", estimate_days: 2 }
    ])
    timeline = Timeline.new(project: @project, today: Date.new(2026, 10, 14))

    row = timeline.rows.find { |candidate| candidate.title == topics(:refresh_tokens).title }
    assert_equal %w[Backend Dashboard], row.bars.map(&:label)
    first, second = row.bars
    assert_equal first.ends_on + 1, second.starts_on
    assert_equal "#{chain.tasks.first.key} · 0 of 2 tasks", row.subtitle
  end

  test "tasks without a topic get their own row and finished work shows as done" do
    rows = Timeline.new(project: @project).rows
    assert_includes rows.map(&:title), "Per-key rate limiting"
    done = rows.find { |row| row.title == "OpenAPI spec published" }
    assert_equal [ :done ], done.bars.map(&:state)
    assert_equal 100, done.percent
  end

  test "work that ends after its due date is flagged at risk" do
    tasks(:rate_limiting).update!(estimate_days: 10, due_on: Date.current + 2)
    row = Timeline.new(project: @project).rows.find { |candidate| candidate.title == "Per-key rate limiting" }
    assert_equal :risk, row.bars.first.state
  end

  test "working-day arithmetic skips weekends" do
    friday = Date.new(2026, 10, 16)
    assert_equal friday, Timeline.add_working_days(friday, 1)
    assert_equal Date.new(2026, 10, 20), Timeline.add_working_days(friday, 3) # Fri, Mon, Tue
    assert_equal Date.new(2026, 10, 19), Timeline.add_working_days(Date.new(2026, 10, 17), 1) # Saturday starts Monday
  end

  test "renders sprint bands, weeks, rows and the today marker" do
    get project_timeline_path(@project)
    assert_response :success
    assert_select ".gantt__band", /Sprint 14/
    assert_select ".gantt__weeks span", Timeline::WEEKS
    assert_select ".gantt__row .gantt__label--feature strong", "Per-key rate limiting"
    assert_select ".gantt__today"
    assert_select ".tab--active", /Timeline/
  end

  test "navigating shifts the window by a week" do
    get project_timeline_path(@project, from: "2026-11-02")
    assert_select ".timeline-nav h1", /Nov 2 – Dec 27/
  end

  test "meetings appear on their day" do
    meeting = topics(:refresh_tokens).meetings.create!(organizer: users(:ines), provider: "zoom", starts_at: Time.current.beginning_of_day + 2.days + 14.hours)
    get project_timeline_path(@project)
    assert_select ".gantt__meeting", /Meeting/
    assert_includes Timeline.new(project: @project).meetings, meeting
  end

  test "exports my due tasks and meetings as an iCalendar feed" do
    tasks(:rate_limiting).update!(assignee: users(:ines), due_on: Date.new(2026, 10, 19))
    topics(:refresh_tokens).meetings.create!(organizer: users(:ines), provider: "zoom", starts_at: 2.days.from_now, join_url: "https://zoom.us/j/1")

    get project_timeline_path(@project, format: :ics)

    assert_response :success
    assert_equal "text/calendar", response.media_type
    assert_includes response.body, "BEGIN:VCALENDAR"
    assert_includes response.body, "SUMMARY:Due: APO-97 Per-key rate limiting"
    assert_includes response.body, "DTSTART;VALUE=DATE:20261019"
    assert_includes response.body, "URL:https://zoom.us/j/1"
    assert_match(/filename="apo-calendar.ics"/, response.headers["Content-Disposition"])
  end
end
