require "test_helper"

class SearchTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    sign_in_as users(:ines)
  end

  test "finds topics by title or body and tasks by title" do
    get search_path(q: "refresh")
    assert_response :success
    assert_select ".spotlight__result strong", topics(:refresh_tokens).title
    assert_select ".spotlight__tab--active", "Everything"
    assert_select ".spotlight__tab", /Topics 1/
  end

  test "task keys find the task directly" do
    get search_path(q: "apo-97")
    assert_select ".spotlight__result strong", "Per-key rate limiting"
    assert_select ".spotlight__text small", /Task APO-97/
  end

  test "searches projects by name or key" do
    get search_path(q: "Apollo")
    assert_select ".spotlight__result strong", "Apollo Gateway"
    assert_select "h4", "Projects"
  end

  test "scoping limits the groups shown but keeps every tab count" do
    get search_path(q: "rate", scope: "tasks")
    assert_select "h4", "Tasks"
    assert_select "h4", text: "Topics", count: 0
    assert_select ".spotlight__tab--active", /Tasks 1/
  end

  test "a blank query lists the pages to jump to" do
    get search_path
    assert_select ".spotlight__hint", /Jump to a page/
    assert_select "h4", "Pages"
    assert_select ".spotlight__result strong", "Account"
    assert_select "h4", text: "Topics", count: 0
  end

  test "pages filter as you type, from the first letter" do
    get search_path(q: "acc")
    assert_select ".spotlight__result[href='#{account_path}']"
    assert_select ".spotlight__result[href='#{appearance_path}']", count: 0
    assert_select "h4", text: "Topics", count: 0
  end

  test "pages match keywords and project areas" do
    get search_path(q: "zoom")
    assert_select ".spotlight__result strong", "Connectors"
    get search_path(q: "apo board")
    assert_select ".spotlight__result[href='#{project_board_path(@project)}'] strong", "Apollo Gateway · Board"
  end

  test "admin-only pages stay hidden from members" do
    sign_in_as users(:jonas)
    get search_path(q: "connectors")
    assert_select ".spotlight__result[href='#{integrations_path}']", count: 0
  end

  test "pages can be the only scope" do
    get search_path(q: "rate", scope: "pages")
    assert_select ".spotlight__result", count: 0
    assert_select ".spotlight__tab--active", /Pages/
  end

  test "no matches says so" do
    get search_path(q: "zzzzzz")
    assert_select ".spotlight__hint", /Nothing matches/
  end

  test "wildcards in the query are matched literally" do
    get search_path(q: "%%")
    assert_select ".spotlight__result", count: 0
  end

  test "results never include projects the user was not invited to" do
    other = Project.create!(name: "Refresh Secret", key: "SEC")
    other.topics.create!(author: users(:jonas), title: "Refresh the secret plans")
    sign_out
    sign_in_as users(:jonas)
    get search_path(q: "refresh")
    assert_select ".spotlight__result strong", text: "Refresh Secret", count: 0
    assert_select ".spotlight__result strong", text: "Refresh the secret plans", count: 0
  end

  test "requires sign-in" do
    sign_out
    get search_path(q: "refresh")
    assert_redirected_to sign_in_path
  end

  test "the app shell carries the palette" do
    get root_path
    assert_select ".shell[data-controller~=spotlight] .spotlight[data-spotlight-target=root]"
    assert_select ".shell[data-controller~=spotlight] button.hint--button"
  end

  test "every settings section can be found from search" do
    { "language" => language_setting_path, "time zone" => language_setting_path, "theme" => appearance_path,
      "email digest" => notification_setting_path, "hotkeys" => keyboard_settings_path, "profile" => account_path }.each do |query, path|
      get search_path(q: query)
      assert_select ".spotlight__result[href='#{path}']", minimum: 1, message: "#{query.inspect} should lead to #{path}"
    end
    get search_path(q: "settings")
    assert_select ".spotlight__result strong", "Settings"
  end

  test "inside a project the search also finds its topics, tasks and chains, before other projects' results" do
    other = Project.create!(name: "Other Place", key: "OTH", color: "teal", icon: "rocket", description: "x", position: 9)
    other.topics.create!(author: users(:jonas), title: "Rate card for partners")
    Chain.create!(project: @project, title: "Rate limit rollout").tasks.create!(project: @project, creator: users(:ines), title: "Ship the rate limiter", chain_position: 1, number: 900)
    Chain.create!(project: other, title: "Rate review chain")

    get search_path(q: "rate", project: @project.key)

    assert_select "h4", "In Apollo Gateway"
    headings = css_select("h4").map(&:text)
    assert_operator headings.index("In Apollo Gateway"), :<, headings.index("Topics")
    assert_select ".spotlight__result strong", "Rate limit rollout"
    assert_select ".spotlight__result strong", "Rate card for partners"
    assert_select ".spotlight__result strong", "Rate review chain"
    assert_select ".spotlight__tab", /Chains 2/
  end

  test "chains are searchable on their own, without a project" do
    Chain.create!(project: @project, title: "Rate limit rollout").tasks.create!(project: @project, creator: users(:ines), title: "Step one", chain_position: 1, number: 901)
    get search_path(q: "rollout", scope: "chains")
    assert_select "h4", "Chains"
    assert_select ".spotlight__result strong", "Rate limit rollout"
    assert_select "h4", text: "Topics", count: 0
  end

  test "the palette knows which project it was opened from" do
    get project_topics_path(@project)
    assert_select "[data-spotlight-url-value=?]", search_path(project: @project.key)
    get root_path
    assert_select "[data-spotlight-url-value=?]", search_path
  end

  test "a project the person cannot see is ignored as the search context" do
    sign_in_as users(:jonas)
    hidden = Project.create!(name: "Hidden", key: "HID", color: "teal", icon: "rocket", description: "x", position: 8)
    get search_path(q: "hid", project: hidden.key)
    assert_response :success
    assert_select "h4", text: /In Hidden/, count: 0
  end
end
