require "test_helper"

class KeyboardSettingsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:ines) }

  def preference = users(:ines).reload.preference

  test "the page lists every shortcut grouped by where it works, with fixed ones locked" do
    get keyboard_settings_path

    assert_response :success
    assert_select ".key-settings h2", text: "Everywhere"
    assert_select ".key-settings h2", text: "Board"
    assert_select ".key-row", Keybindings.all.count { |entry| entry[:context] != :sign_in }
    assert_select ".key-capture", Keybindings.customizable.count { |entry| entry[:context] != :sign_in }
    assert_select ".key--fixed", 3 # back, submit, open project
    assert_select "input[type=hidden][name='keybindings[board]'][value='g b']"
  end

  test "the sign-in keys are not offered" do
    get keyboard_settings_path
    assert_select "input[name='keybindings[sign_in_google]']", count: 0
  end

  test "saving a remap stores it and the app uses it immediately" do
    patch keyboard_settings_path, params: { keybindings: { board: "g x", new_topic: "w" } }
    assert_redirected_to keyboard_settings_path
    assert_equal({ "board" => "g x", "new_topic" => "w" }, preference.keybindings)

    get project_board_path(projects(:apollo))
    assert_select "a.tab--active[data-hotkey='g x']"
  end

  test "unchanged rows are not stored" do
    patch keyboard_settings_path, params: { keybindings: { board: "g b", topics: "g t" } }
    assert_empty preference.keybindings
  end

  test "a browser-owned combination is refused with an explanation and nothing is saved" do
    patch keyboard_settings_path, params: { keybindings: { board: "ctrl+s" } }

    assert_response :unprocessable_content
    assert_select ".key-problems li", /can't be used for Board/
    assert_empty preference.keybindings
  end

  test "conflicts are listed and the entered values stay on the page" do
    patch keyboard_settings_path, params: { keybindings: { board: "g t" } }

    assert_response :unprocessable_content
    assert_select ".key-problems li", /would both use/
    assert_select "input[name='keybindings[board]'][value='g t']"
    assert_empty preference.keybindings
  end

  test "fixed shortcuts cannot be changed through the form either" do
    patch keyboard_settings_path, params: { keybindings: { back: "q", submit: "q" } }
    assert_empty preference.keybindings # unpermitted ids are ignored
  end

  test "reset all returns every shortcut to its default" do
    preference.remap_keybindings!("board" => "g x")
    delete keyboard_settings_path
    assert_redirected_to keyboard_settings_path
    assert_empty preference.keybindings
  end

  test "remaps are per person" do
    patch keyboard_settings_path, params: { keybindings: { board: "g x" } }
    sign_out
    sign_in_as users(:jonas)
    get project_board_path(projects(:apollo))
    assert_select "a.tab--active[data-hotkey='g b']"
  end

  test "the settings menu links to the shortcut settings and requires sign-in" do
    get account_path
    assert_select ".settings__nav a[href=?]", keyboard_settings_path, text: /Keyboard shortcuts/
    sign_out
    get keyboard_settings_path
    assert_redirected_to sign_in_path
  end
end
