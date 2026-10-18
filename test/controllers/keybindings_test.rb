require "test_helper"

class KeybindingsTest < ActionDispatch::IntegrationTest
  VIEW_GLOBS = %w[app/views/**/*.erb app/helpers/**/*.rb].freeze

  test "the registry loads with every group and unique key specs per group" do
    assert_equal %i[global project page], Keybindings.groups.keys
    Keybindings.groups.each do |group, entries|
      keys = entries.values.map { |entry| entry[:keys] }
      assert_equal keys.uniq, keys, "duplicate shortcut inside #{group}"
    end
  end

  test "no shortcut collides with a browser-owned Ctrl/Cmd+letter combo" do
    taken = %w[ctrl+s ctrl+p ctrl+f ctrl+t ctrl+w ctrl+n ctrl+r ctrl+l ctrl+d ctrl+a ctrl+c ctrl+v ctrl+x ctrl+z]
    assert_empty Keybindings.valid_specs & taken
  end

  test "project navigation chords are all distinct" do
    chords = Keybindings.groups[:project].values.map { |entry| entry[:keys] }
    assert_equal 6, chords.uniq.size
    assert(chords.all? { |chord| chord.start_with?("g ") })
  end

  test "every data-hotkey used in the views is a registered shortcut" do
    used = VIEW_GLOBS.flat_map { |glob| Dir[Rails.root.join(glob)] }.flat_map do |file|
      File.read(file).scan(/hotkey: "([^"]+)"|data-hotkey="([^"]+)"/).flatten.compact
    end.uniq

    assert_empty used - Keybindings.valid_specs, "unregistered shortcuts: add them to config/keybindings.yml"
  end

  test "labels render as key caps" do
    assert_equal "G B", Keybindings.label(:board)
    assert_equal "Ctrl Enter", Keybindings.label(:submit)
    assert_equal "Esc", Keybindings.label(:back)
    assert_raises(KeyError) { Keybindings.keys(:nonsense) }
  end

  test "project tabs show the shortcut of every tab except the current one" do
    sign_in_as users(:ines)
    get project_board_path(projects(:apollo))

    assert_select ".tab--active .key", count: 0
    assert_select ".tab:not(.tab--active) .key", 5
    assert_select "a.tab[data-hotkey='g t'] .key", "G T"
    assert_select "a.tab[data-hotkey='g l']"
    assert_select "a.tab--active[data-hotkey='g b']"
  end

  test "the same holds on any other tab" do
    sign_in_as users(:ines)
    get project_topics_path(projects(:apollo))
    assert_select ".tab--active .key", count: 0
    assert_select ".tab[data-hotkey='g b'] .key", "G B"
  end

  test "the shell offers global navigation shortcuts and the help dialog" do
    sign_in_as users(:ines)
    get root_path

    assert_select "body[data-controller~=hotkeys]"
    assert_select "a[data-hotkey='g h']"
    assert_select "a[data-hotkey='g o']"
    assert_select "a[data-hotkey='g u']"
    assert_select "button[data-hotkey='?']"
    assert_select ".keyhelp dt", Keybindings.all.size
    assert_select ".keyhelp kbd", text: "G B"
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
