require "test_helper"

class AccountAndAppearanceTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:ines) }

  test "account shows the profile, role and sign-in method" do
    users(:ines).identities.create!(provider: "google", uid: "g1", email: "ines@orbitlabs.dev")
    get account_path

    assert_response :success
    assert_select "h2", "Inês Machado"
    assert_select ".tag--role", /Admin/
    assert_select ".signin-note", /Signed in with Google/
    assert_select ".avatar-option", 10
    assert_select ".settings-list li", 6
  end

  test "managers see the projects they manage next to their role" do
    ProjectMembership.create!(project: projects(:apollo), user: users(:ines), role: "manager")
    get account_path
    assert_select ".tag--role", /Admin · apollo gateway/
  end

  test "notification defaults match the design until changed" do
    get account_path
    assert_select "input[type=checkbox][name='notifications[mention_or_reply]'][checked]"
    assert_select "input[type=checkbox][name='notifications[new_topic]'][checked]", count: 0
  end

  test "saving updates profile, preferences and notifications together" do
    patch account_path, params: {
      user: { name: "Inês M.", avatar_icon: "rocket", avatar_color: "plum" },
      preference: { email_frequency: "weekly", quiet_hours_start: "21:00", quiet_hours_end: "07:30" },
      notifications: { new_topic: "1", mention_or_reply: "0" }
    }

    assert_redirected_to account_path
    user = users(:ines).reload
    assert_equal [ "Inês M.", "rocket", "plum" ], [ user.name, user.avatar_icon, user.avatar_color ]
    assert_equal "weekly", user.preference.email_frequency
    assert_equal "07:30", user.preference.quiet_hours_end.strftime("%H:%M")
    assert user.subscribed_to?("new_topic")
    assert_not user.subscribed_to?("mention_or_reply")
    assert user.subscribed_to?("task_assigned") # untouched kinds keep their default
  end

  test "invalid profile changes are rejected without saving anything" do
    patch account_path, params: { user: { name: "", avatar_icon: "rocket", avatar_color: "plum" }, preference: { email_frequency: "weekly" } }
    assert_response :unprocessable_content
    assert_equal "cat", users(:ines).reload.avatar_icon
    assert_equal "daily_digest", users(:ines).preference.email_frequency
  end

  test "unknown notification kinds are ignored" do
    patch account_path, params: { user: { name: "Inês" }, preference: { email_frequency: "instant" }, notifications: { bogus: "1" } }
    assert_redirected_to account_path
    assert_equal 0, users(:ines).notification_subscriptions.where(kind: "bogus").count
  end

  test "appearance lists every background and accent" do
    get appearance_path
    assert_response :success
    assert_select ".theme-option", 4
    assert_select ".accent-option", 5
  end

  test "choosing a palette saves it and themes every page" do
    patch appearance_path, params: { preference: { theme_bg: "night", theme_accent: "teal" } }
    assert_redirected_to appearance_path

    get root_path
    assert_select "html[data-bg=night][data-accent=teal]"
  end

  test "reset returns to paper and orange" do
    users(:ines).preference.update!(theme_bg: "sage", theme_accent: "plum")
    patch appearance_path, params: { reset: "1" }
    assert_equal %w[paper orange], users(:ines).preference.reload.slice(:theme_bg, :theme_accent).values
  end

  test "an unknown palette is rejected" do
    patch appearance_path, params: { preference: { theme_bg: "neon", theme_accent: "orange" } }
    assert_redirected_to appearance_path
    assert_equal "paper", users(:ines).preference.reload.theme_bg
  end

  test "visitors see the default theme on the sign-in page" do
    sign_out
    get sign_in_path
    assert_select "html[data-bg=paper][data-accent=orange]"
  end
end
