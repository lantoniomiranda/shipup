require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include IconHelper
  NOW = Time.utc(2026, 10, 17, 12)

  test "time_ago_label uses compact wording" do
    assert_equal "No activity yet", time_ago_label(nil)
    assert_equal "Active just now", time_ago_label(NOW - 20.seconds, now: NOW)
    assert_equal "Active 12 min ago", time_ago_label(NOW - 12.minutes, now: NOW)
    assert_equal "Active 3h ago", time_ago_label(NOW - 3.hours, now: NOW)
    assert_equal "Active yesterday", time_ago_label(NOW - 30.hours, now: NOW)
    assert_equal "Active 4d ago", time_ago_label(NOW - 4.days, now: NOW)
  end

  test "daypart_icon follows the local hour of a zone" do
    assert_equal "sun", daypart_icon("Europe/Lisbon", now: Time.utc(2026, 10, 17, 14))
    assert_equal "moon", daypart_icon("Asia/Tokyo", now: Time.utc(2026, 10, 17, 14)) # 23:00 local
    assert_equal "sunrise", daypart_icon("Europe/Lisbon", now: Time.utc(2026, 10, 17, 7)) # 08:00 local
  end

  test "projects_path_for keeps the default URL clean" do
    assert_equal root_path, projects_path_for("active")
    assert_equal root_path(status: "completed"), projects_path_for("completed")
  end

  test "avatar renders the chosen icon on the user's colour, with initials as the label" do
    html = avatar(users(:ines), size: :sm)
    assert_includes html, "<svg"
    assert_includes html, "(IM)"
    assert_includes html, "avatar--mustard"
    assert_includes html, "avatar--sm"
  end
end
