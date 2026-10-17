require "test_helper"

class Integrations::OauthClientTest < ActiveSupport::TestCase
  include IntegrationCredentials

  setup do
    @redirect = "https://shipup.test/integrations/zoom/callback"
  end

  test "builds an authorize URL with scopes, state and provider extras" do
    with_integration_credentials do
      url = Integrations::OauthClient.new(Integrations.provider("google_meet"), redirect_uri: @redirect).authorize_url(state: "abc")
      query = Rack::Utils.parse_query(URI(url).query)

      assert_equal "accounts.google.com", URI(url).host
      assert_equal "abc", query["state"]
      assert_equal "offline", query["access_type"]
      assert_includes query["scope"], "calendar.events"
      assert_equal "test-google_client_id", query["client_id"]
    end
  end

  test "exchanges a code using HTTP basic auth for Zoom" do
    with_integration_credentials do
      stub = stub_request(:post, "https://zoom.us/oauth/token")
        .with(headers: { "Authorization" => "Basic #{Base64.strict_encode64('test-zoom_client_id:test-zoom_client_secret')}" },
              body: hash_including("grant_type" => "authorization_code", "code" => "the-code"))
        .to_return(status: 200, body: { access_token: "at", refresh_token: "rt", expires_in: 3600, scope: "meeting:write" }.to_json, headers: { "Content-Type" => "application/json" })

      tokens = Integrations::OauthClient.new(Integrations.provider("zoom"), redirect_uri: @redirect).exchange(code: "the-code")

      assert_requested stub
      assert_equal "at", tokens.access_token
      assert_equal "rt", tokens.refresh_token
      assert_in_delta 1.hour.from_now.to_f, tokens.expires_at.to_f, 5
    end
  end

  test "sends client credentials in the body for GitHub" do
    with_integration_credentials do
      stub = stub_request(:post, "https://github.com/login/oauth/access_token")
        .with(body: hash_including("client_id" => "test-github_client_id", "client_secret" => "test-github_client_secret"))
        .to_return(status: 200, body: { access_token: "gho_x", scope: "repo" }.to_json, headers: { "Content-Type" => "application/json" })

      tokens = Integrations::OauthClient.new(Integrations.provider("github"), redirect_uri: @redirect).exchange(code: "c")

      assert_requested stub
      assert_equal "gho_x", tokens.access_token
      assert_nil tokens.refresh_token
    end
  end

  test "raises a readable error when the provider rejects the code" do
    with_integration_credentials do
      stub_request(:post, "https://github.com/login/oauth/access_token")
        .to_return(status: 200, body: { error: "bad_verification_code", error_description: "The code passed is incorrect" }.to_json, headers: { "Content-Type" => "application/json" })

      error = assert_raises(Integrations::Error) do
        Integrations::OauthClient.new(Integrations.provider("github"), redirect_uri: @redirect).exchange(code: "nope")
      end
      assert_match(/incorrect/, error.message)
    end
  end

  test "refreshing keeps the old refresh token when the provider issues none" do
    with_integration_credentials do
      stub_request(:post, "https://github.com/login/oauth/access_token")
        .to_return(status: 200, body: { access_token: "new" }.to_json, headers: { "Content-Type" => "application/json" })

      tokens = Integrations::OauthClient.new(Integrations.provider("github"), redirect_uri: @redirect).refresh(refresh_token: "keep-me")
      assert_equal "new", tokens.access_token
      assert_equal "keep-me", tokens.refresh_token
    end
  end
end
