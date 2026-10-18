require "test_helper"

class TimeZoneTest < ActionDispatch::IntegrationTest
  setup { @user = User.create!(name: "Newcomer", email: "new@orbitlabs.dev") }

  test "a new person follows their browser's time zone" do
    assert_equal "UTC", @user.time_zone
    assert @user.time_zone_auto?

    sign_in_as @user
    cookies[:browser_time_zone] = "Europe/Lisbon"
    get root_path

    assert_equal "Europe/Lisbon", @user.reload.time_zone
    assert_select ".clock[data-zone='Europe/Lisbon'] strong", "Lisbon"
  end

  test "the first clock is the person's own, styled like the others" do
    sign_in_as @user
    cookies[:browser_time_zone] = "Asia/Tokyo"
    get root_path
    assert_select ".clock:first-child[data-zone='Asia/Tokyo'] strong", "Tokyo"
  end

  test "an explicit choice is never overwritten by the browser" do
    @user.update!(time_zone: "America/Chicago", time_zone_set_by_user: true)
    sign_in_as @user
    cookies[:browser_time_zone] = "Europe/Lisbon"
    get root_path
    assert_equal "America/Chicago", @user.reload.time_zone
  end

  test "garbage in the cookie is ignored" do
    sign_in_as @user
    cookies[:browser_time_zone] = "Mars/Olympus_Mons"
    get root_path
    assert_response :success
    assert_equal "UTC", @user.reload.time_zone
  end

  test "picking a zone in the account stops following the browser" do
    sign_in_as @user
    patch account_path, params: { user: { name: "Newcomer", time_zone: "Europe/Berlin", time_zone_auto: "0" }, preference: { email_frequency: "instant" } }
    assert_equal [ "Europe/Berlin", false ], [ @user.reload.time_zone, @user.time_zone_auto? ]

    cookies[:browser_time_zone] = "Europe/Lisbon"
    get root_path
    assert_equal "Europe/Berlin", @user.reload.time_zone
  end

  test "ticking automatic resumes following the browser" do
    @user.update!(time_zone: "Europe/Berlin", time_zone_set_by_user: true)
    sign_in_as @user
    patch account_path, params: { user: { name: "Newcomer", time_zone: "Europe/Berlin", time_zone_auto: "1" }, preference: { email_frequency: "instant" } }
    assert @user.reload.time_zone_auto?

    cookies[:browser_time_zone] = "Europe/Lisbon"
    get root_path
    assert_equal "Europe/Lisbon", @user.reload.time_zone
  end

  test "an invalid zone is rejected" do
    sign_in_as @user
    patch account_path, params: { user: { name: "Newcomer", time_zone: "Nowhere/Land", time_zone_auto: "0" }, preference: { email_frequency: "instant" } }
    assert_response :unprocessable_content
    assert_equal "UTC", @user.reload.time_zone
  end

  test "the account page offers the zones with their offsets and the automatic switch" do
    sign_in_as @user
    get account_path
    assert_select "select[name='user[time_zone]'] option[value='Europe/Lisbon']"
    assert_select "input[name='user[time_zone_auto]'][type=checkbox][checked]"
    assert_includes User.time_zone_options.map(&:first), "(UTC+00:00) Lisbon"
  end

  test "dates render in the person's zone, not UTC" do
    ProjectMembership.create!(project: projects(:apollo), user: @user)
    topic = projects(:apollo).topics.create!(author: users(:jonas), title: "Late night topic", created_at: Time.utc(2026, 9, 12, 23, 30))
    @user.update!(time_zone: "Asia/Tokyo", time_zone_set_by_user: true)
    sign_in_as @user
    travel_to Time.utc(2026, 10, 17) do
      get project_topics_path(projects(:apollo))
    end
    assert_select ".topic-row", text: /Late night topic.*13 Sep/m # 23:30 UTC is already the 13th in Tokyo
  end

  test "the browser time zone script ships with every page" do
    get sign_in_path
    assert_select "body[data-controller~=timezone]"
  end
end
