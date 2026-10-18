require "test_helper"

class GithubRepositoriesControllerTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json" }.freeze
  REPOS = [ { id: 555, full_name: "orbitlabs/gateway" }, { id: 556, full_name: "orbitlabs/mobile" } ].freeze

  setup do
    @connection = IntegrationConnection.create!(provider: "github", external_account: "orbitlabs", connected_by: users(:ines), access_token: "gho_x")
    stub_request(:get, %r{https://api.github.com/user/repos}).to_return(status: 200, body: REPOS.to_json, headers: JSON_HEADERS)
    ENV["GITHUB_WEBHOOK_SECRET"] = "whsec"
    sign_in_as users(:ines)
  end

  teardown { ENV.delete("GITHUB_WEBHOOK_SECRET") }

  test "lists projects with the repositories the account can reach" do
    get github_repositories_path
    assert_response :success
    assert_select ".repo-project", 1
    assert_select "select option", text: "orbitlabs/gateway"
  end

  test "requires a GitHub connection" do
    @connection.destroy
    get github_repositories_path
    assert_redirected_to integrations_path
  end

  test "members cannot manage repositories" do
    sign_out
    sign_in_as users(:jonas)
    get github_repositories_path
    assert_response :forbidden
  end

  test "linking a repository stores it and registers the webhook" do
    hook = stub_request(:post, "https://api.github.com/repos/orbitlabs/gateway/hooks")
      .with(body: hash_including("events" => [ "pull_request" ]))
      .to_return(status: 201, body: "{}", headers: JSON_HEADERS)

    assert_difference "GithubRepository.count", 1 do
      post github_repositories_path, params: { project_id: "APO", external_id: "555" }
    end

    assert_requested hook
    assert_redirected_to github_repositories_path
    assert_equal "orbitlabs/gateway", projects(:apollo).github_repositories.sole.full_name
  end

  test "a failed webhook registration leaves nothing linked" do
    stub_request(:post, "https://api.github.com/repos/orbitlabs/gateway/hooks").to_return(status: 403, body: "{}", headers: JSON_HEADERS)

    assert_no_difference "GithubRepository.count" do
      post github_repositories_path, params: { project_id: "APO", external_id: "555" }
    end
    assert_match(/Couldn't link/, flash[:alert])
  end

  test "only repositories the account can reach can be linked" do
    assert_no_difference "GithubRepository.count" do
      post github_repositories_path, params: { project_id: "APO", external_id: "999" }
    end
    assert_match(/Pick a repository/, flash[:alert])
  end

  test "unlinking removes the repository" do
    repository = projects(:apollo).github_repositories.create!(integration_connection: @connection, external_id: 555, full_name: "orbitlabs/gateway")
    assert_difference "GithubRepository.count", -1 do
      delete github_repository_path(repository)
    end
  end

  test "the setup page offers GitHub and links to repository management when connected" do
    get integrations_path
    assert_select ".tool__text strong", "GitHub"
    assert_select "a", text: /Choose repositories/
  end
end
