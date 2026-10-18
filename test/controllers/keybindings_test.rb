require "test_helper"

class KeybindingsRegistryTest < ActiveSupport::TestCase
  test "every shortcut has a known context, a valid default and a label" do
    Keybindings.all.each do |entry|
      assert Keybindings::CONTEXTS.key?(entry[:context]), "#{entry[:id]}: unknown context #{entry[:context]}"
      assert Keybindings.valid_spec?(entry[:keys]), "#{entry[:id]}: invalid default #{entry[:keys].inspect}"
      assert entry[:label].present?
    end
  end

  test "the defaults never collide with each other" do
    defaults = Keybindings::SHORTCUTS.keys.index_with { |id| Keybindings.default_keys(id) }
    assert_empty Keybindings.conflicts(defaults)
  end

  test "no default is a combination the browser owns" do
    owned = %w[ctrl+s ctrl+p ctrl+f ctrl+t ctrl+w ctrl+n ctrl+r ctrl+l ctrl+d ctrl+a ctrl+c ctrl+v ctrl+x ctrl+z]
    assert_empty Keybindings.valid_specs & owned
  end

  test "labels render as key caps" do
    assert_equal "G B", Keybindings.label(:board, user: nil)
    assert_equal "Ctrl Enter", Keybindings.label(:submit, user: nil)
    assert_equal "Esc", Keybindings.label("escape")
    assert_equal "Shift →", Keybindings.label("shift+arrowright")
    assert_raises(KeyError) { Keybindings.keys(:nonsense, user: nil) }
  end

  test "only web-safe combinations are valid" do
    %w[n 7 / ? g\ x shift+arrowleft ctrl+enter escape arrowright].each { |spec| assert Keybindings.valid_spec?(spec), spec }
    [ "ctrl+s", "cmd+k", "alt+n", "ctrl+shift+p", "tab", "f5", "space", "enter", "N", "g x y", "gg", "", " g", "g  x", "ñ", nil ].each do |spec|
      assert_not Keybindings.valid_spec?(spec), spec.inspect
    end
  end

  test "escape and ctrl+enter can never be assigned to something else" do
    assert_not Keybindings.assignable_spec?("escape")
    assert_not Keybindings.assignable_spec?("ctrl+enter")
    assert_includes Keybindings.validate("board" => "escape").join, "can't be used"
  end

  test "fixed shortcuts cannot be remapped" do
    assert_includes Keybindings.validate("back" => "x").join, "can't be changed"
    assert_includes Keybindings.validate("submit" => "x").join, "can't be changed"
  end

  test "unknown ids are reported" do
    assert_includes Keybindings.validate("bogus" => "x").join, "not a shortcut"
  end

  test "a valid remapping has no problems" do
    assert_empty Keybindings.validate("board" => "g x", "new_topic" => "w")
  end

  test "two shortcuts that can be active together cannot share a key" do
    problems = Keybindings.validate("board" => "g t") # topics already uses g t, both are project navigation
    assert_equal 1, problems.size
    assert_match(/both use/, problems.first)
  end

  test "shortcuts on pages that never show together may share a key" do
    # new_topic (topics list) and new_project (projects page) are both "n" by default, and
    # timeline "today" and the task timer are both "t".
    assert_empty Keybindings.validate("new_topic" => "q", "new_project" => "q")
    assert_empty Keybindings.validate("timeline_today" => "t", "toggle_timer" => "t")
  end

  test "a global shortcut collides with a page shortcut using the same key" do
    assert_not_empty Keybindings.validate("add_client" => "/") # "/" is search, active everywhere
  end

  test "a single key may not be the first key of a chord that is active with it" do
    problems = Keybindings.validate("add_client" => "g") # every "g x" navigation chord starts with g
    assert_match(/clashes/, problems.first)
  end

  test "a chord may not start with a key another active shortcut uses on its own" do
    assert_not_empty Keybindings.validate("projects" => "n x") # "n" alone is new topic/project
  end

  test "single-key handlers refuse chords and the board advance needs shift+arrow" do
    assert_match(/single key/, Keybindings.validate("reply" => "r x").join)
    assert_match(/Shift plus an arrow/, Keybindings.validate("board_advance" => "x").join)
    assert_match(/can't use Shift/, Keybindings.validate("board_next_card" => "shift+arrowup").join)
    assert_empty Keybindings.validate("board_advance" => "shift+arrowup")
  end

  test "the sign-in page's keys are exempt from the global ones" do
    assert_empty Keybindings.conflicts(Keybindings::SHORTCUTS.keys.index_with { |id| Keybindings.default_keys(id) }) # g (Google) vs the g chords
  end

  test "an override is used, but junk and fixed overrides fall back to the default" do
    ines = users(:ines)
    ines.create_preference! unless ines.preference.persisted?
    ines.preference.update_columns(keybindings: { "board" => "g x", "back" => "q", "analytics" => "ctrl+s" })

    assert_equal "g x", Keybindings.keys(:board, user: ines)
    assert_equal "escape", Keybindings.keys(:back, user: ines)
    assert_equal "g a", Keybindings.keys(:analytics, user: ines)
    assert_equal "G X", Keybindings.label(:board, user: ines)
    assert_equal "g b", Keybindings.keys(:board, user: users(:jonas)) # other people are unaffected
    assert_equal "g b", Keybindings.keys(:board, user: nil)
  end
end

class UserPreferenceKeybindingsTest < ActiveSupport::TestCase
  setup { @preference = users(:ines).preference.tap { |preference| preference.save! } }

  test "remapping stores only real changes" do
    @preference.remap_keybindings!("board" => "g x", "topics" => "g t", "timeline" => "")
    assert_equal({ "board" => "g x" }, @preference.reload.keybindings)
  end

  test "invalid or conflicting remaps raise with readable messages and save nothing" do
    error = assert_raises(ActiveRecord::RecordInvalid) { @preference.remap_keybindings!("board" => "ctrl+s") }
    assert_match(/can't be used/, error.message)
    assert_raises(ActiveRecord::RecordInvalid) { @preference.remap_keybindings!("board" => "g t") }
    assert_empty @preference.reload.keybindings
  end

  test "reset clears everything" do
    @preference.remap_keybindings!("board" => "g x")
    @preference.reset_keybindings!
    assert_empty @preference.reload.keybindings
  end

  test "unknown ids are dropped when remapping through the form" do
    @preference.remap_keybindings!("bogus" => "x", "board" => "g x")
    assert_equal({ "board" => "g x" }, @preference.reload.keybindings)
  end
end

class KeybindingsViewsTest < ActionDispatch::IntegrationTest
  VIEW_GLOBS = %w[app/views/**/*.erb app/helpers/**/*.rb].freeze

  test "views never hard-code a shortcut: everything goes through the registry" do
    literals = VIEW_GLOBS.flat_map { |glob| Dir[Rails.root.join(glob)] }.flat_map do |file|
      File.read(file).scan(/hotkey: "([^"]+)"|data-hotkey="([^"<]+)"/).flatten.compact
    end
    assert_empty literals, "hard-coded shortcut(s) #{literals.inspect}: use hotkey_data(:id) / Keybindings.keys(:id)"
  end

  test "every id the views ask for exists" do
    ids = VIEW_GLOBS.flat_map { |glob| Dir[Rails.root.join(glob)] }.flat_map do |file|
      File.read(file).scan(/(?:hotkey_data|key_hint|Keybindings\.(?:keys|label))\(:(\w+)/).flatten
    end.uniq
    assert_empty ids - Keybindings::SHORTCUTS.keys.map(&:to_s), "unknown shortcut ids in views"
  end

  test "project tabs show the shortcut of every tab except the current one" do
    sign_in_as users(:ines)
    get project_board_path(projects(:apollo))

    assert_select ".tab--active .key", count: 0
    assert_select ".tab:not(.tab--active) .key", 6
    assert_select "a.tab[data-hotkey='g t'] .key", "G T"
    assert_select "a.tab--active[data-hotkey='g b']"
  end

  test "project tab shortcuts are never hidden by the stylesheet" do
    css = Rails.root.join("app/assets/stylesheets/components/project_header.css").read
    assert_no_match(/\.tab[^{]*\.key[^{]*\{[^}]*display:\s*none/, css)
  end

  test "remapped keys show up everywhere they appear" do
    users(:ines).preference.update!(keybindings: { "board" => "g x", "notifications" => "g i", "new_topic" => "w" })
    sign_in_as users(:ines)

    get project_topics_path(projects(:apollo))
    assert_select "a.tab[data-hotkey='g x'] .key", "G X"
    assert_select "a[data-hotkey='g i'][title*='G I']"
    assert_select "a.btn--primary[data-hotkey='w'] .key", "W"
    assert_select "[data-hotkey='g b']", count: 0
    assert_select ".keyhelp dt", text: "Board"
    assert_select ".keyhelp kbd", text: "G X"
  end

  test "the board page hands its keys to the board controller" do
    users(:ines).preference.update!(keybindings: { "board_next_card" => "n", "board_advance" => "shift+arrowup" })
    sign_in_as users(:ines)
    get project_board_path(projects(:apollo))

    keys = JSON.parse(css_select(".board-page").first["data-board-keys-value"])
    assert_equal({ "next_card" => "n", "prev_card" => "k", "next_column" => "l", "prev_column" => "h", "advance" => "shift+arrowup" }, keys)
  end

  test "the search key is configurable too" do
    users(:ines).preference.update!(keybindings: { "search" => "f" })
    sign_in_as users(:ines)
    get root_path
    assert_select ".shell[data-spotlight-key-value=f]"
  end

  test "visitors on the sign-in page use the defaults" do
    get sign_in_path
    assert_select "[data-hotkey='g']"
    assert_select "[data-hotkey='m']"
  end

  test "the shell offers global navigation shortcuts and the help dialog" do
    sign_in_as users(:ines)
    get root_path

    assert_select "body[data-controller~=hotkeys]"
    assert_select "a[data-hotkey='g h']"
    assert_select "a[data-hotkey='g o']"
    assert_select "a[data-hotkey='g u']"
    assert_select "button[data-hotkey='?']"
    assert_select ".keyhelp dt", Keybindings.all.count { |entry| entry[:context] != :sign_in }
    assert_select ".keyhelp a", text: "Customize"
  end

  test "primary actions submit with Ctrl+Enter, not browser-owned combos" do
    sign_in_as users(:ines)
    get account_path
    assert_select "[data-hotkey='ctrl+enter']"
    assert_select "[data-hotkey='ctrl+s']", count: 0
  end

  test "the task timer is on T instead of Space" do
    sign_in_as users(:ines)
    get project_task_path(projects(:apollo), tasks(:rate_limiting))
    assert_select "button[data-hotkey='t']"
  end
end
