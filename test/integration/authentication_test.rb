require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "visitors see the public landing page at the root" do
    get root_path
    assert_response :success
    assert_select "h1", /Talk it through/
    assert_select "a.btn--primary[href=?]", sign_in_path
    assert_select ".hero__note", /Invite-only/
  end

  test "signed-in people get the dashboard at the same address" do
    sign_in_as users(:ines)
    get root_path
    assert_select ".project-card h2", "Apollo Gateway"
    assert_select "h1", count: 1
    assert_select ".landing", count: 0
  end

  test "protected pages still send visitors to sign in" do
    get account_path
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
    get "/account?from=link"
    sign_in_as users(:ines)
    assert_redirected_to "http://www.example.com/account?from=link"
  end

  test "signing out ends the session" do
    sign_in_as users(:ines)
    sign_out
    assert_redirected_to sign_in_path
    get root_path
    assert_select ".landing" # back to the public page
    get account_path
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

  test "someone nobody invited is turned away with an explanation" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = omniauth_hash("google_oauth2", uid: "new", email: "stranger@nowhere.io", name: "Stranger")

    assert_no_difference "User.count" do
      post "/auth/google_oauth2"
      follow_redirect!
    end
    assert_redirected_to sign_in_path
    follow_redirect!
    assert_select ".sign-in__alert", /invite-only/
  end

  test "an invited person signs in for the first time and lands in their workspace" do
    workspaces(:orbit).invitations.create!(email: "newbie@orbitlabs.dev", role: "manager")
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = omniauth_hash("google_oauth2", uid: "newbie", email: "newbie@orbitlabs.dev", name: "New Bie")

    post "/auth/google_oauth2"
    follow_redirect!
    follow_redirect!

    assert_response :success
    assert_equal "manager", User.find_by!(email: "newbie@orbitlabs.dev").role_in(workspaces(:orbit))
  end
end
