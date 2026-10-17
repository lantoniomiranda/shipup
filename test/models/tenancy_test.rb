require "test_helper"

class TenancyTest < ActiveSupport::TestCase
  test "provisioning creates the tenant and invites its first admin" do
    workspace = Workspace.provision!(name: "Globex Corp", admin_email: "Hank@Globex.com", seats_limit: 10, invited_by: users(:ines))

    assert workspace.active?
    assert workspace.plan_trial?
    assert_equal "globex-corp", workspace.slug
    assert_in_delta Workspace::TRIAL_DAYS.days.from_now.to_f, workspace.trial_ends_at.to_f, 5
    invitation = workspace.invitations.sole
    assert_equal "hank@globex.com", invitation.email
    assert invitation.admin?
    assert_equal users(:ines), invitation.invited_by
  end

  test "paid plans have no trial end" do
    assert_nil Workspace.provision!(name: "Paid Co", admin_email: "a@paid.co", plan: "team").trial_ends_at
  end

  test "provisioning is atomic" do
    assert_no_difference "Workspace.count" do
      assert_raises(ActiveRecord::RecordInvalid) { Workspace.provision!(name: "Broken Co", admin_email: "not-an-email") }
    end
  end

  test "seats count members and pending invitations against the limit" do
    workspace = Workspace.create!(name: "Small Co", seats_limit: 2)
    workspace.memberships.create!(user: users(:ines), role: "admin")
    assert_equal 1, workspace.seats_used
    assert_equal 1, workspace.seats_left

    workspace.invitations.create!(email: "new@small.co")
    assert_not workspace.seat_available?
    assert_not workspace.invitations.build(email: "one-more@small.co").valid?
  end

  test "workspaces without a limit have unlimited seats" do
    workspace = Workspace.create!(name: "Big Co")
    assert workspace.seat_available?
    assert_nil workspace.seats_left
  end

  test "suspending and reactivating records the reason" do
    workspace = Workspace.create!(name: "Late Payer")
    workspace.suspend!("Invoice overdue")
    assert workspace.suspended?
    assert_equal "Invoice overdue", workspace.suspended_reason
    assert_not_nil workspace.suspended_at

    workspace.reactivate!
    assert workspace.active?
    assert_nil workspace.suspended_reason
  end

  test "trial expiry is detected" do
    workspace = Workspace.create!(name: "Trial Co", trial_ends_at: 1.day.ago)
    assert workspace.trial_expired?
    workspace.update!(plan: "team")
    assert_not workspace.trial_expired?
  end

  test "search finds tenants by name or slug" do
    Workspace.create!(name: "Initech")
    assert_equal [ "Initech" ], Workspace.search("nitec").pluck(:name)
    assert_includes Workspace.search("orbit"), workspaces(:orbit)
    assert_equal Workspace.count, Workspace.search("").count
  end

  test "invalid status and plan are rejected" do
    assert_not Workspace.new(name: "X", status: "gone").valid?
    assert_not Workspace.new(name: "X", plan: "free-forever").valid?
  end

  test "joinable_for needs an active workspace that allows domain join" do
    workspace = Workspace.create!(name: "Acme", email_domain: "acme.io", allow_domain_join: true)
    assert_equal workspace, Workspace.joinable_for("sofia@ACME.io")
    assert_nil Workspace.joinable_for("sofia@other.io")
    workspace.suspend!
    assert_nil Workspace.joinable_for("sofia@acme.io")
  end
end

class InvitationTest < ActiveSupport::TestCase
  setup { @workspace = workspaces(:orbit) }

  test "emails are normalised and roles validated" do
    invitation = @workspace.invitations.create!(email: "  New@Person.IO ", role: "manager")
    assert_equal "new@person.io", invitation.email
    assert_not @workspace.invitations.build(email: "x@y.io", role: "owner").valid?
  end

  test "each invitation gets a unique token" do
    first = @workspace.invitations.create!(email: "a@x.io")
    second = @workspace.invitations.create!(email: "b@x.io")
    assert_not_equal first.token, second.token
    assert_operator first.token.length, :>=, 20
  end

  test "only one pending invitation per email and workspace" do
    @workspace.invitations.create!(email: "a@x.io")
    assert_raises(ActiveRecord::RecordNotUnique) { @workspace.invitations.new(email: "a@x.io").save!(validate: false) }
  end

  test "a revoked invitation can be sent again" do
    @workspace.invitations.create!(email: "a@x.io").revoke!
    assert @workspace.invitations.create!(email: "a@x.io").pending?
  end

  test "people who are already members cannot be invited" do
    assert_not @workspace.invitations.build(email: users(:jonas).email).valid?
  end

  test "accepting creates the membership once and keeps the invited role" do
    invitation = @workspace.invitations.create!(email: "new@x.io", role: "admin")
    user = User.create!(name: "New", email: "new@x.io")
    invitation.accept!(user)

    assert_equal "admin", user.role_in(@workspace)
    assert_not invitation.pending?
    assert_no_difference "Membership.count" do
      invitation.accept!(user)
    end
  end

  test "revoked invitations cannot be picked up at sign-in" do
    invitation = @workspace.invitations.create!(email: "new@x.io")
    invitation.revoke!
    user = User.create!(name: "New", email: "new@x.io")
    Invitation.accept_all_for(user)
    assert_empty user.workspaces
  end
end
