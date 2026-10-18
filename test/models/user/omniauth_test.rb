require "test_helper"

class User::OmniauthTest < ActiveSupport::TestCase
  def auth(provider: "google_oauth2", uid: "g-1", email: "sofia@acme.io", name: "Sofia Reyes")
    OmniAuth::AuthHash.new(provider: provider, uid: uid, info: { email: email, name: name })
  end

  setup { @workspace = Workspace.create!(name: "Acme", email_domain: "acme.io") }

  test "strangers cannot sign up" do
    assert_no_difference [ "User.count", "Workspace.count", "Identity.count" ] do
      assert_raises(User::Omniauth::NotInvited) { User.from_omniauth(auth(email: "nobody@random.org")) }
    end
  end

  test "an invitation lets the person in with the invited role and is consumed" do
    invitation = @workspace.invitations.create!(email: "tom@elsewhere.io", role: "manager")
    user = User.from_omniauth(auth(uid: "g-2", email: "Tom@Elsewhere.io", name: "Tom Weber"))

    assert_equal "manager", user.role_in(@workspace)
    assert_equal [ "google" ], user.identities.pluck(:provider)
    assert_not invitation.reload.pending?
    assert_not_nil invitation.accepted_at
  end

  test "company-domain join is off unless the workspace allows it" do
    assert_raises(User::Omniauth::NotInvited) { User.from_omniauth(auth) }
  end

  test "workspaces that allow it admit teammates on their email domain as members" do
    @workspace.update!(allow_domain_join: true)
    user = User.from_omniauth(auth)
    assert_equal "member", user.role_in(@workspace)
  end

  test "a suspended workspace admits nobody on its domain" do
    @workspace.update!(allow_domain_join: true)
    @workspace.suspend!
    assert_raises(User::Omniauth::NotInvited) { User.from_omniauth(auth) }
  end

  test "domain join stops when the plan has no seats left" do
    @workspace.update!(allow_domain_join: true, seats_limit: 0)
    assert_raises(User::Omniauth::NotInvited) { User.from_omniauth(auth) }
  end

  test "platform admins from the environment can sign up without a workspace" do
    ENV["PLATFORM_ADMIN_EMAILS"] = "boss@shipup.dev, other@shipup.dev"
    user = User.from_omniauth(auth(uid: "p-1", email: "boss@shipup.dev", name: "Boss"))
    assert user.platform_admin?
    assert_empty user.workspaces
  ensure
    ENV.delete("PLATFORM_ADMIN_EMAILS")
  end

  test "SUPERADMIN_EMAILS is accepted as an alias" do
    ENV["SUPERADMIN_EMAILS"] = "boss@shipup.dev"
    assert User.platform_admin_email?("Boss@shipup.dev")
    assert_not User.platform_admin_email?("other@shipup.dev")
  ensure
    ENV.delete("SUPERADMIN_EMAILS")
  end

  test "existing users are promoted to platform admin when their email is listed" do
    ENV["PLATFORM_ADMIN_EMAILS"] = users(:ines).email
    assert User.from_omniauth(auth(uid: "p-2", email: users(:ines).email)).platform_admin?
  ensure
    ENV.delete("PLATFORM_ADMIN_EMAILS")
  end

  test "signing in again returns the same user without duplicating anything" do
    @workspace.invitations.create!(email: "sofia@acme.io")
    user = User.from_omniauth(auth)
    assert_no_difference [ "User.count", "Identity.count", "Membership.count" ] do
      assert_equal user, User.from_omniauth(auth)
    end
  end

  test "a second provider with the same email links to the existing user" do
    @workspace.invitations.create!(email: "sofia@acme.io")
    user = User.from_omniauth(auth)
    assert_no_difference "User.count" do
      assert_equal user, User.from_omniauth(auth(provider: "entra_id", uid: "m-1"))
    end
    assert_equal %w[google microsoft], user.identities.order(:provider).pluck(:provider)
  end

  test "an existing user picks up invitations to other workspaces when they sign in" do
    other = Workspace.create!(name: "Second Co")
    other.invitations.create!(email: users(:ines).email, role: "manager")
    user = User.from_omniauth(auth(uid: "g-9", email: users(:ines).email))

    assert_equal "manager", user.role_in(other)
    assert_equal "admin", user.role_in(workspaces(:orbit)) # still in the first tenant
  end

  test "invitations to a suspended workspace stay pending" do
    other = Workspace.create!(name: "Paused Co")
    invitation = other.invitations.create!(email: users(:jonas).email)
    other.suspend!
    User.from_omniauth(auth(uid: "g-8", email: users(:jonas).email))
    assert invitation.reload.pending?
  end

  test "rejects a provider response without an email" do
    assert_raises(ArgumentError) { User.from_omniauth(auth(email: "")) }
  end
end
