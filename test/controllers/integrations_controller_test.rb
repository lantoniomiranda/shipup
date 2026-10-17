require "test_helper"

class IntegrationsControllerTest < ActionDispatch::IntegrationTest
  include IntegrationCredentials

  JSON_HEADERS = { "Content-Type" => "application/json" }.freeze

  test "shows the meeting tools to admins" do
    sign_in_as users(:ines)
    get integrations_path
    assert_response :success
    assert_select ".tool", 3
    assert_select ".tool__text strong", text: "Zoom"
  end

  test "members cannot open admin setup" do
    sign_in_as users(:jonas)
    get integrations_path
    assert_response :forbidden
  end

  test "connecting redirects to the provider with a state token" do
    with_integration_credentials do
      sign_in_as users(:ines)
      post connect_integration_path(provider: "zoom")

      assert_response :redirect
      assert_match %r{\Ahttps://zoom\.us/oauth/authorize\?}, response.location
      assert_match(/state=\h{48}/, response.location)
    end
  end

  test "connecting is refused politely when the server has no credentials" do
    sign_in_as users(:ines)
    post connect_integration_path(provider: "zoom")
    assert_redirected_to integrations_path
    assert_match(/isn't configured/, flash[:alert])
  end

  test "the callback stores an encrypted connection for the workspace" do
    with_integration_credentials do
      sign_in_as users(:ines)
      post connect_integration_path(provider: "zoom")
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]

      stub_request(:post, "https://zoom.us/oauth/token")
        .to_return(status: 200, body: { access_token: "at", refresh_token: "rt", expires_in: 3600 }.to_json, headers: JSON_HEADERS)
      stub_request(:get, "https://api.zoom.us/v2/users/me").to_return(status: 200, body: { email: "ops@orbitlabs.dev" }.to_json, headers: JSON_HEADERS)

      assert_difference -> { workspaces(:orbit).integration_connections.count }, 1 do
        get integration_callback_path(provider: "zoom", code: "abc", state: state)
      end

      assert_redirected_to integrations_path
      connection = workspaces(:orbit).connection_for("zoom")
      assert_equal "ops@orbitlabs.dev", connection.external_account
      assert_equal "at", connection.access_token
      assert_equal users(:ines), connection.connected_by
    end
  end

  test "the callback rejects a mismatched state" do
    with_integration_credentials do
      sign_in_as users(:ines)
      post connect_integration_path(provider: "zoom")

      assert_no_difference "IntegrationConnection.count" do
        get integration_callback_path(provider: "zoom", code: "abc", state: "forged")
      end
      assert_redirected_to integrations_path
      assert_match(/expired/, flash[:alert])
    end
  end

  test "an unknown provider is a 404" do
    sign_in_as users(:ines)
    post "/integrations/slack/connection"
    assert_response :not_found
  end

  test "choosing a connected meeting tool saves it for the workspace" do
    workspaces(:orbit).integration_connections.create!(provider: "zoom", external_account: "ops@orbitlabs.dev", connected_by: users(:ines))
    sign_in_as users(:ines)

    patch meeting_tool_path, params: { provider: "zoom" }

    assert_redirected_to root_path
    assert_equal "zoom", workspaces(:orbit).reload.meeting_provider
  end

  test "choosing a tool that is not connected is refused" do
    sign_in_as users(:ines)
    patch meeting_tool_path, params: { provider: "google_meet" }
    assert_redirected_to integrations_path
    assert_nil workspaces(:orbit).reload.meeting_provider
  end
end
