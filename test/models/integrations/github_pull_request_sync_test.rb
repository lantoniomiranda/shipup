require "test_helper"

class Integrations::GithubPullRequestSyncTest < ActiveSupport::TestCase
  setup do
    connection = workspaces(:orbit).integration_connections.create!(provider: "github", external_account: "orbitlabs", connected_by: users(:ines))
    @repository = projects(:apollo).github_repositories.create!(integration_connection: connection, external_id: 555, full_name: "orbitlabs/gateway")
  end

  def payload(title: "APO-97: per-key rate limiting", state: "open", merged_at: nil, branch: "feature/rate-limit", body: nil)
    {
      "repository" => { "id" => 555 },
      "pull_request" => { "number" => 471, "title" => title, "html_url" => "https://github.com/orbitlabs/gateway/pull/471", "state" => state,
                          "merged_at" => merged_at, "body" => body, "user" => { "login" => "jonask" }, "head" => { "ref" => branch } }
    }
  end

  test "creates the pull request and links the task named in the title" do
    pull_request = Integrations::Github::PullRequestSync.call(payload).sole

    assert_equal 471, pull_request.number
    assert pull_request.open?
    assert_equal [ tasks(:rate_limiting) ], pull_request.tasks.to_a
  end

  test "links tasks mentioned in the branch name or description too" do
    pull_request = Integrations::Github::PullRequestSync.call(payload(title: "Tidy", branch: "apo-97-x".upcase, body: "Closes APO-104")).sole
    assert_equal [ tasks(:rate_limiting), tasks(:spec_published) ].map(&:id).sort, pull_request.tasks.ids.sort
  end

  test "ignores keys from other projects" do
    pull_request = Integrations::Github::PullRequestSync.call(payload(title: "ATL-97 something")).sole
    assert_empty pull_request.tasks
  end

  test "updates state on later events without duplicating links" do
    Integrations::Github::PullRequestSync.call(payload)
    pull_request = nil
    assert_no_difference [ "PullRequest.count", "TaskPullRequest.count" ] do
      pull_request = Integrations::Github::PullRequestSync.call(payload(state: "closed", merged_at: "2026-10-18T10:00:00Z")).sole
    end
    assert pull_request.merged?
  end

  test "does nothing for repositories no project has linked" do
    assert_empty Integrations::Github::PullRequestSync.call(payload.merge("repository" => { "id" => 1 }))
  end
end
