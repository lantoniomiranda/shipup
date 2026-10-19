require "test_helper"

class AccountAndAppearanceTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:ines) }

  test "account shows the profile, role and sign-in method" do
    users(:ines).identities.create!(provider: "google", uid: "g1", email: "ines@orbitlabs.dev")
    get account_path

    assert_response :success
    assert_select "h2", "Inês Machado"
    assert_select ".tag--role", /Superadmin/
    assert_select ".signin-note", /Signed in with Google/
    assert_select ".avatar-option", 10
    assert_select ".settings__nav .settings__item--active", /Account/
  end

  test "project admins see the projects they manage next to their role" do
    get account_path
    assert_select ".tag--role", /Superadmin · Apollo Gateway/
  end

  test "notification defaults match the design until changed" do
    get notification_setting_path
    assert_select "input[type=checkbox][name='notifications[mention_or_reply]'][checked]"
    assert_select "input[type=checkbox][name='notifications[new_topic]'][checked]", count: 0
  end

  test "saving the account updates the profile" do
    patch account_path, params: { user: { name: "Inês M.", avatar_icon: "rocket", avatar_color: "plum" } }

    assert_redirected_to account_path
    user = users(:ines).reload
    assert_equal [ "Inês M.", "rocket", "plum" ], [ user.name, user.avatar_icon, user.avatar_color ]
  end

  test "saving notification settings updates preferences and subscriptions together" do
    patch notification_setting_path, params: {
      preference: { email_frequency: "weekly", quiet_hours_start: "21:00", quiet_hours_end: "07:30" },
      notifications: { new_topic: "1", mention_or_reply: "0" }
    }

    assert_redirected_to notification_setting_path
    user = users(:ines).reload
    assert_equal "weekly", user.preference.email_frequency
    assert_equal "07:30", user.preference.quiet_hours_end.strftime("%H:%M")
    assert user.subscribed_to?("new_topic")
    assert_not user.subscribed_to?("mention_or_reply")
    assert user.subscribed_to?("task_assigned") # untouched kinds keep their default
  end

  test "the notification settings page lists every kind of notice" do
    get notification_setting_path
    assert_select ".settings-list li", 6
  end

  test "saving language and time stores the working hours" do
    patch language_setting_path, params: { user: { time_zone: "Europe/Berlin", time_zone_auto: "0" }, preference: { work_day_start: "08:00", work_day_end: "16:30" } }

    assert_redirected_to language_setting_path
    preference = users(:ines).reload.preference
    assert_equal [ "08:00", "16:30" ], [ preference.work_day_start.strftime("%H:%M"), preference.work_day_end.strftime("%H:%M") ]
  end

  test "invalid profile changes are rejected without saving anything" do
    patch account_path, params: { user: { name: "", avatar_icon: "rocket", avatar_color: "plum" } }
    assert_response :unprocessable_content
    assert_equal "cat", users(:ines).reload.avatar_icon
  end

  test "unknown notification kinds are ignored" do
    patch notification_setting_path, params: { preference: { email_frequency: "instant" }, notifications: { bogus: "1" } }
    assert_redirected_to notification_setting_path
    assert_equal 0, users(:ines).notification_subscriptions.where(kind: "bogus").count
  end

  test "settings is one place: the old pages are gone and /settings lands on the account" do
    get "/settings"
    assert_redirected_to "/settings/account"
    get "/integrations"
    assert_redirected_to "/settings/connectors"
  end

  test "the settings menu shows connectors to superadmins only" do
    get account_path
    assert_select ".settings__nav a[href=?]", integrations_path
    sign_in_as users(:jonas)
    get account_path
    assert_select ".settings__nav a[href=?]", integrations_path, count: 0
  end

  test "appearance lists every background and accent" do
    get appearance_path
    assert_response :success
    assert_select ".theme-option", 5 # four palettes plus "match system"
    assert_select ".accent-option", 6 # five accents plus custom
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

class AppearanceSettingsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:ines) }

  def preference = users(:ines).reload.preference

  test "the page offers every control" do
    get appearance_path
    assert_select ".theme-option", 5
    assert_select ".accent-option", 6
    assert_select "input[type=color][name='preference[custom_accent]']"
    assert_select ".font-option", Appearance::FONTS.size
    assert_select "input[name='preference[density]']", 3
    assert_select "input[name='preference[text_size]']", 4
    assert_select "input[name='preference[corners]']", 3
    assert_select "input[type=checkbox].switch", 3
    assert_select "button", text: /Reset menu order/
  end

  test "saving applies everything to the html element on every page" do
    patch appearance_path, params: { preference: { theme_bg: "night", theme_accent: "custom", custom_accent: "#3366cc", font: "inter", density: "compact",
                                                   text_size: "large", corners: "round", hard_shadows: "0", high_contrast: "1", reduce_motion: "1" } }
    assert_redirected_to appearance_path

    get root_path
    assert_select "html[data-bg=night][data-accent=custom][data-font=inter][data-corners=round][data-shadows=flat][data-contrast=high][data-motion=reduced]"
    assert_select "html[style*='--accent: #3366cc']"
    assert_select "html[style*='--zoom: 1.012']" # 0.92 * 1.1
    assert_select "link[href*='family=Inter']"
  end

  test "match system is saved as such" do
    patch appearance_path, params: { preference: { theme_bg: "system" } }
    get root_path
    assert_select "html[data-bg=system]"
  end

  test "an invalid look is refused and nothing changes" do
    patch appearance_path, params: { preference: { font: "comic", corners: "round" } }
    assert_redirected_to appearance_path
    assert_match(/isn't available/, flash[:alert])
    assert_equal "square", preference.corners
  end

  test "a custom accent needs a real colour" do
    patch appearance_path, params: { preference: { theme_accent: "custom", custom_accent: "blue" } }
    assert_match(/isn't available/, flash[:alert])
    assert_equal "orange", preference.theme_accent
  end

  test "reset restores the defaults and the menu order" do
    preference.update!(font: "mono", corners: "round", project_tab_order: %w[board topics])
    patch appearance_path, params: { reset: "1" }
    assert_equal [ "exo", "square", [] ], [ preference.font, preference.corners, preference.project_tab_order ]
  end

  test "other people keep their own look" do
    patch appearance_path, params: { preference: { font: "serif", theme_bg: "sage" } }
    sign_out
    sign_in_as users(:jonas)
    get root_path
    assert_select "html[data-bg=paper][data-font=exo]"
  end

  test "visitors see the default look" do
    sign_out
    get sign_in_path
    assert_select "html[data-bg=paper][data-accent=orange][data-font=exo]"
  end
end

class ProjectTabOrderTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:ines) }

  test "dropping a tab saves the person's order and the header uses it" do
    patch project_tab_order_path, params: { order: %w[board analytics topics backlog timeline clients people] }, as: :json
    assert_response :no_content

    get project_topics_path(projects(:apollo))
    assert_equal %w[board analytics topics backlog timeline clients people], css_select(".tabs .tab").map { |tab| tab["data-tab-key"] }
  end

  test "unknown tabs are ignored and missing ones keep their default place after" do
    patch project_tab_order_path, params: { order: %w[clients nonsense] }, as: :json
    get project_topics_path(projects(:apollo))
    assert_equal %w[clients topics backlog board timeline people analytics], css_select(".tabs .tab").map { |tab| tab["data-tab-key"] }
  end

  test "the tabs are draggable and wired to the sorter" do
    get project_topics_path(projects(:apollo))
    assert_select ".tabs[data-controller=tab-sort][data-tab-sort-url-value=?]", project_tab_order_path
    assert_select ".tabs a.tab[draggable=true]", 7
  end

  test "each person has their own order" do
    patch project_tab_order_path, params: { order: %w[analytics] }, as: :json
    sign_out
    sign_in_as users(:jonas)
    get project_topics_path(projects(:apollo))
    assert_equal ProjectTabs::KEYS, css_select(".tabs .tab").map { |tab| tab["data-tab-key"] }
  end

  test "resetting puts the tabs back in the default order" do
    users(:ines).preference.update!(project_tab_order: %w[analytics])
    delete project_tab_order_path
    assert_empty users(:ines).reload.preference.project_tab_order
  end

  test "the order endpoint needs a signed-in person" do
    sign_out
    patch project_tab_order_path, params: { order: %w[board] }, as: :json
    assert_redirected_to sign_in_path
  end

  test "keyboard shortcuts keep working on reordered tabs" do
    patch project_tab_order_path, params: { order: %w[analytics board] }, as: :json
    get project_board_path(projects(:apollo))
    assert_select "a.tab[data-hotkey='g a']"
    assert_select "a.tab--active[data-hotkey='g b']"
  end
end
