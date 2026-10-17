require "test_helper"

class User::OmniauthTest < ActiveSupport::TestCase
  def auth(provider: "google_oauth2", uid: "g-1", email: "sofia@acme.io", name: "Sofia Reyes")
    OmniAuth::AuthHash.new(provider: provider, uid: uid, info: { email: email, name: name })
  end

  test "creates the user, identity, workspace and admin membership on first sign-in" do
    user = User.from_omniauth(auth)

    assert user.persisted?
    assert_equal "sofia@acme.io", user.email
    assert_equal [ "google" ], user.identities.pluck(:provider)
    workspace = user.workspaces.sole
    assert_equal "acme.io", workspace.email_domain
    assert_equal "admin", user.role_in(workspace)
  end

  test "teammates with the same company domain join the existing workspace as members" do
    first = User.from_omniauth(auth)
    second = User.from_omniauth(auth(uid: "g-2", email: "tom@acme.io", name: "Tom Weber"))

    assert_equal first.workspaces.sole, second.workspaces.sole
    assert_equal "member", second.role_in(second.workspaces.sole)
  end

  test "people on free mail providers each get their own workspace" do
    a = User.from_omniauth(auth(uid: "g-3", email: "a@gmail.com", name: "A"))
    b = User.from_omniauth(auth(uid: "g-4", email: "b@gmail.com", name: "B"))

    assert_not_equal a.workspaces.sole, b.workspaces.sole
    assert_nil a.workspaces.sole.email_domain
  end

  test "signing in again returns the same user without duplicating anything" do
    user = User.from_omniauth(auth)
    assert_no_difference [ "User.count", "Identity.count", "Workspace.count" ] do
      assert_equal user, User.from_omniauth(auth)
    end
  end

  test "a second provider with the same email links to the existing user" do
    user = User.from_omniauth(auth)
    assert_no_difference "User.count" do
      assert_equal user, User.from_omniauth(auth(provider: "entra_id", uid: "m-1"))
    end
    assert_equal %w[google microsoft], user.identities.order(:provider).pluck(:provider)
  end

  test "rejects a provider response without an email" do
    assert_raises(ArgumentError) { User.from_omniauth(auth(email: "")) }
  end
end
