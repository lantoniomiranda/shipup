require "test_helper"

class User::OmniauthTest < ActiveSupport::TestCase
  def auth(provider: "google_oauth2", uid: "g-1", email: "sofia@acme.io", name: "Sofia Reyes")
    OmniAuth::AuthHash.new(provider: provider, uid: uid, info: { email: email, name: name })
  end

  setup { @project = projects(:apollo) }

  def with_superadmins(*emails)
    original = Rails.configuration.x.superadmin_emails
    Rails.configuration.x.superadmin_emails = emails
    yield
  ensure
    Rails.configuration.x.superadmin_emails = original
  end

  test "strangers cannot sign up" do
    assert_no_difference [ "User.count", "Identity.count" ] do
      assert_raises(User::Omniauth::NotInvited) { User.from_omniauth(auth(email: "nobody@random.org")) }
    end
  end

  test "an invitation lets the person in with the invited role and is consumed" do
    invitation = @project.invitations.create!(email: "tom@elsewhere.io", role: "admin")
    user = User.from_omniauth(auth(uid: "g-2", email: "Tom@Elsewhere.io", name: "Tom Weber"))

    assert_equal "admin", @project.project_memberships.find_by!(user: user).role
    assert_equal [ "google" ], user.identities.pluck(:provider)
    assert_not user.superadmin?
    assert_not invitation.reload.pending?
    assert_not_nil invitation.accepted_at
  end

  test "a revoked invitation does not let anyone in" do
    @project.invitations.create!(email: "tom@elsewhere.io").revoke!
    assert_raises(User::Omniauth::NotInvited) { User.from_omniauth(auth(email: "tom@elsewhere.io")) }
  end

  test "the same company domain is not enough to get in" do
    assert_raises(User::Omniauth::NotInvited) { User.from_omniauth(auth(email: "someone@orbitlabs.dev")) }
  end

  test "superadmins from the config can sign up without an invitation" do
    with_superadmins("boss@shipup.dev", "other@shipup.dev") do
      user = User.from_omniauth(auth(uid: "p-1", email: "boss@shipup.dev", name: "Boss"))
      assert user.superadmin?
      assert_empty user.projects
    end
  end

  test "superadmin is derived from the config, so removing an email revokes it" do
    with_superadmins(users(:jonas).email) { assert users(:jonas).superadmin? }
    assert_not users(:jonas).superadmin?
    assert users(:ines).superadmin? # the test config
  end

  test "an invited project admin is not a superadmin" do
    @project.invitations.create!(email: "tom@elsewhere.io", role: "admin")
    assert_not User.from_omniauth(auth(uid: "g-3", email: "tom@elsewhere.io")).superadmin?
  end

  test "signing in again returns the same user without duplicating anything" do
    @project.invitations.create!(email: "sofia@acme.io")
    user = User.from_omniauth(auth)
    assert_no_difference [ "User.count", "Identity.count", "ProjectMembership.count" ] do
      assert_equal user, User.from_omniauth(auth)
    end
  end

  test "a second provider with the same email links to the existing user" do
    @project.invitations.create!(email: "sofia@acme.io")
    user = User.from_omniauth(auth)
    assert_no_difference "User.count" do
      assert_equal user, User.from_omniauth(auth(provider: "entra_id", uid: "m-1"))
    end
    assert_equal %w[google microsoft], user.identities.order(:provider).pluck(:provider)
  end

  test "an existing user picks up invitations to other projects when they sign in" do
    other = Project.create!(name: "Second", key: "SEC")
    other.invitations.create!(email: users(:jonas).email, role: "admin")
    user = User.from_omniauth(auth(uid: "g-9", email: users(:jonas).email))

    assert_equal "admin", other.project_memberships.find_by!(user: user).role
    assert_equal "member", projects(:apollo).project_memberships.find_by!(user: user).role # still on the first project
  end

  test "rejects a provider response without an email" do
    assert_raises(ArgumentError) { User.from_omniauth(auth(email: "")) }
  end
end
