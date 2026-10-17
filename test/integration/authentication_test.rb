require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "visitors are sent to the sign-in page" do
    get root_path
    assert_redirected_to sign_in_path
  end

  test "sign-in page offers Google and Microsoft only" do
    get sign_in_path
    assert_response :success
    assert_select "button", text: /Continue with Google/
    assert_select "button", text: /Continue with Microsoft/
    assert_select "input[type=password]", count: 0
  end

  test "signing in with Google lands on the projects home" do
    sign_in_as users(:ines)
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "signing in with Microsoft works too" do
    sign_in_as users(:jonas), provider: "entra_id"
    follow_redirect!
    assert_response :success
  end

  test "returns the user to the page they originally asked for" do
    get "/?from=link"
    sign_in_as users(:ines)
    assert_redirected_to "http://www.example.com/?from=link"
  end

  test "signing out ends the session" do
    sign_in_as users(:ines)
    sign_out
    assert_redirected_to sign_in_path
    get root_path
    assert_redirected_to sign_in_path
  end

  test "a failed OAuth round-trip returns to sign-in with a message" do
    get auth_failure_path
    assert_redirected_to sign_in_path
    follow_redirect!
    assert_select ".sign-in__alert"
  end

  test "a provider without an email is rejected" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = omniauth_hash("google_oauth2", uid: "x", email: "", name: "No Email")
    post "/auth/google_oauth2"
    follow_redirect!
    assert_redirected_to sign_in_path
  end
end
