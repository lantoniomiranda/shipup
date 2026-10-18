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
end
