require "test_helper"

class AppearanceTest < ActiveSupport::TestCase
  def preference(**attrs) = UserPreference.find_by!(user: users(:ines)).tap { |preference| preference.assign_attributes(attrs) }

  test "defaults render the original look" do
    html = Appearance.new(preference).html_attributes
    assert_equal({ bg: "paper", accent: "orange", font: "exo", corners: "square", shadows: "hard", contrast: "normal", motion: "normal" }, html[:data])
    assert_equal "--zoom: 1.0", html[:style]
  end

  test "density and text size multiply into one zoom" do
    assert_equal 0.92, Appearance.new(preference(density: "compact")).zoom
    assert_in_delta 1.1 * 1.08, Appearance.new(preference(density: "spacious", text_size: "large")).zoom, 0.0001
  end

  test "switches map to attribute values" do
    data = Appearance.new(preference(hard_shadows: false, high_contrast: true, reduce_motion: true)).html_attributes[:data]
    assert_equal [ "flat", "high", "reduced" ], data.values_at(:shadows, :contrast, :motion)
  end

  test "a custom accent derives its whole family from one colour" do
    style = Appearance.new(preference(theme_accent: "custom", custom_accent: "#3366CC")).style
    assert_includes style, "--accent: #3366CC"
    assert_includes style, "--accent-soft: color-mix(in srgb, #3366CC 28%, var(--surface))"
    assert_includes style, "--on-accent: #FFFFFF" # dark blue needs light text
    assert_equal "custom", Appearance.new(preference(theme_accent: "custom", custom_accent: "#3366CC")).html_attributes[:data][:accent]
  end

  test "light accents get dark text, dark ones get light text" do
    appearance = Appearance.new(preference)
    assert_equal "#2B211A", appearance.readable_on("#EBB43B")
    assert_equal "#2B211A", appearance.readable_on("#FFFFFF")
    assert_equal "#FFFFFF", appearance.readable_on("#1B2A5C")
    assert_equal "#FFFFFF", appearance.readable_on("#000000")
  end

  test "a custom accent without a colour falls back to the named one" do
    assert_not_includes Appearance.new(preference(theme_accent: "custom", custom_accent: nil)).style, "--accent:"
  end

  test "web fonts: only non-system fonts load a stylesheet" do
    assert_match(/family=Inter/, Appearance.new(preference(font: "inter")).font_stylesheet_url)
    assert_nil Appearance.new(preference(font: "system")).font_stylesheet_url
  end

  test "people who are not signed in get the defaults" do
    assert_equal "paper", Appearance.for(nil).html_attributes[:data][:bg]
  end
end

class AppearancePreferenceTest < ActiveSupport::TestCase
  def preference = UserPreference.find_by!(user: users(:ines)) # a fresh record each call

  test "every option is validated" do
    { theme_bg: "neon", theme_accent: "pink", font: "comic", density: "tiny", text_size: "huge", corners: "pointy" }.each do |field, bad|
      assert_not preference.tap { |p| p[field] = bad }.valid?, field
    end
  end

  test "custom accents must be six-digit hex colours and are required when selected" do
    assert preference.tap { |p| p.custom_accent = "#aabbcc" }.valid?
    [ "red", "#abc", "#gggggg", "aabbcc" ].each { |bad| assert_not preference.tap { |p| p.custom_accent = bad }.valid?, bad }
    assert_not preference.tap { |p| p.theme_accent = "custom"; p.custom_accent = nil }.valid?
  end

  test "match system is an accepted background" do
    assert preference.tap { |p| p.theme_bg = "system" }.valid?
  end

  test "reset_appearance! restores every default" do
    pref = preference
    pref.update!(theme_bg: "night", theme_accent: "custom", custom_accent: "#112233", font: "mono", density: "compact", text_size: "large", corners: "round", hard_shadows: false, high_contrast: true, reduce_motion: true)
    pref.reset_appearance!
    assert_equal UserPreference::DEFAULT_APPEARANCE.transform_keys(&:to_s), pref.reload.attributes.slice(*UserPreference::DEFAULT_APPEARANCE.keys.map(&:to_s))
  end

  test "project tab order keeps known tabs in the order given" do
    pref = preference
    pref.reorder_project_tabs!(%w[board topics bogus analytics])
    assert_equal %w[board topics analytics], pref.reload.project_tab_order
  end

  test "ProjectTabs puts the person's tabs first and the rest after in the default order" do
    users(:ines).preference.update!(project_tab_order: %w[analytics board])
    assert_equal %w[analytics board topics backlog timeline clients people], ProjectTabs.for(users(:ines)).map { |tab| tab[:key] }
    assert_equal ProjectTabs::KEYS, ProjectTabs.for(users(:jonas)).map { |tab| tab[:key] }
    assert_equal ProjectTabs::KEYS, ProjectTabs.for(nil).map { |tab| tab[:key] }
  end
end
