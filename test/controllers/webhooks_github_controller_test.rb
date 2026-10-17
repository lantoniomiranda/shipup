require "test_helper"

class Webhooks::GithubControllerTest < ActionDispatch::IntegrationTest
  SECRET = "whsec".freeze

  setup do
    ENV["GITHUB_WEBHOOK_SECRET"] = SECRET
    connection = workspaces(:orbit).integration_connections.create!(provider: "github", external_account: "orbitlabs", connected_by: users(:ines))
    projects(:apollo).github_repositories.create!(integration_connection: connection, external_id: 555, full_name: "orbitlabs/gateway")
    @body = { repository: { id: 555 }, pull_request: { number: 9, title: "APO-97 limit", html_url: "https://github.com/o/r/pull/9", state: "open", head: { ref: "x" } } }.to_json
  end

  teardown { ENV.delete("GITHUB_WEBHOOK_SECRET") }

  def deliver(body: @body, signature: "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', SECRET, body)}", event: "pull_request")
    post "/webhooks/github", params: body, headers: { "Content-Type" => "application/json", "X-Hub-Signature-256" => signature, "X-GitHub-Event" => event }
  end

  test "a correctly signed pull_request event is stored and linked" do
    assert_difference "PullRequest.count", 1 do
      deliver
    end
    assert_response :ok
    assert_equal [ tasks(:rate_limiting) ], PullRequest.last.tasks.to_a
  end

  test "a bad signature is rejected" do
    assert_no_difference "PullRequest.count" do
      deliver(signature: "sha256=deadbeef")
    end
    assert_response :unauthorized
  end

  test "is rejected when no secret is configured" do
    ENV.delete("GITHUB_WEBHOOK_SECRET")
    deliver(signature: "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', '', @body)}")
    assert_response :unauthorized
  end

  test "other events are acknowledged and ignored" do
    assert_no_difference "PullRequest.count" do
      deliver(event: "ping")
    end
    assert_response :ok
  end

  test "malformed JSON is a bad request" do
    deliver(body: "{nope")
    assert_response :bad_request
  end
end
