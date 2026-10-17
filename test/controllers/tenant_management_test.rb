require "test_helper"

class TenantManagementTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { @orbit = workspaces(:orbit) }

  # ---- People -----------------------------------------------------------------
  test "workspace admins see members and pending invitations" do
    @orbit.invitations.create!(email: "new@orbitlabs.dev", role: "manager", invited_by: users(:ines))
    sign_in_as users(:ines)
    get memberships_path

    assert_response :success
    assert_select "tbody tr", 3 # two members + one invitation row
    assert_select ".client-cell strong", "Inês Machado"
    assert_select "td strong", "new@orbitlabs.dev"
    assert_select "select[name='membership[role]']", 2
  end

  test "members who are not admins cannot open the page" do
    sign_in_as users(:jonas)
    get memberships_path
    assert_response :forbidden
  end

  test "the top bar offers the People shortcut to admins only" do
    sign_in_as users(:ines)
    get root_path
    assert_select "a[data-hotkey='g e']"
    sign_out
    sign_in_as users(:jonas)
    get root_path
    assert_select "a[data-hotkey='g e']", count: 0
  end

  test "admins invite people, who are emailed" do
    sign_in_as users(:ines)
    assert_enqueued_emails 1 do
      post invitations_path, params: { invitation: { email: "Sofia@Orbitlabs.dev", role: "manager" } }
    end
    invitation = @orbit.invitations.pending.sole
    assert_equal "sofia@orbitlabs.dev", invitation.email
    assert_equal users(:ines), invitation.invited_by
    assert invitation.manager?
  end

  test "inviting someone who is already a member is refused" do
    sign_in_as users(:ines)
    assert_no_difference "Invitation.count" do
      post invitations_path, params: { invitation: { email: users(:jonas).email, role: "member" } }
    end
    assert_match(/already a member/, flash[:alert])
  end

  test "seat limits apply to tenant admins too" do
    @orbit.update!(seats_limit: 2)
    sign_in_as users(:ines)
    assert_no_difference "Invitation.count" do
      post invitations_path, params: { invitation: { email: "third@orbitlabs.dev", role: "member" } }
    end
    assert_match(/No seats left/, flash[:alert])
  end

  test "invitations can be resent and revoked" do
    invitation = @orbit.invitations.create!(email: "new@orbitlabs.dev")
    sign_in_as users(:ines)
    assert_enqueued_emails(1) { post resend_invitation_path(invitation) }
    delete invitation_path(invitation)
    assert_not invitation.reload.pending?
  end

  test "an admin cannot touch another tenant's invitations" do
    rival = Workspace.create!(name: "Rival")
    foreign = rival.invitations.create!(email: "x@rival.io")
    sign_in_as users(:ines)
    delete invitation_path(foreign)
    assert_response :not_found
    assert foreign.reload.pending?
  end

  test "roles can be changed" do
    sign_in_as users(:ines)
    membership = @orbit.memberships.find_by!(user: users(:jonas))
    patch membership_path(membership), params: { membership: { role: "manager" } }
    assert_equal "manager", membership.reload.role
  end

  test "the last admin cannot be demoted or removed" do
    sign_in_as users(:ines)
    mine = @orbit.memberships.find_by!(user: users(:ines))

    patch membership_path(mine), params: { membership: { role: "member" } }
    assert_equal "admin", mine.reload.role
    assert_match(/at least one admin/, flash[:alert])

    delete membership_path(mine)
    assert Membership.exists?(mine.id)
  end

  test "an unknown role is rejected" do
    sign_in_as users(:ines)
    membership = @orbit.memberships.find_by!(user: users(:jonas))
    patch membership_path(membership), params: { membership: { role: "owner" } }
    assert_equal "member", membership.reload.role
  end

  test "removing a member ends their access but keeps their account and words" do
    ProjectMembership.create!(project: projects(:apollo), user: users(:jonas))
    message = topics(:refresh_tokens).messages.create!(author: users(:jonas), body: "Still here")
    sign_in_as users(:ines)

    delete membership_path(@orbit.memberships.find_by!(user: users(:jonas)))

    assert_nil users(:jonas).role_in(@orbit)
    assert_empty projects(:apollo).project_memberships.where(user: users(:jonas))
    assert User.exists?(users(:jonas).id)
    assert TopicMessage.exists?(message.id)
  end

  test "memberships of other tenants cannot be edited" do
    rival = Workspace.create!(name: "Rival")
    foreign = rival.memberships.create!(user: users(:staff), role: "admin")
    sign_in_as users(:ines)
    patch membership_path(foreign), params: { membership: { role: "member" } }
    assert_response :not_found
    delete membership_path(foreign)
    assert_response :not_found
  end

  # ---- workspace switching -------------------------------------------------------------
  test "people in several workspaces can switch between them" do
    other = Workspace.create!(name: "Second Co")
    other.memberships.create!(user: users(:ines), role: "admin")
    sign_in_as users(:ines)

    get root_path
    assert_select ".workspaces__item--current[title='Orbit Labs']"
    assert_select "button.workspaces__item[title='Switch to Second Co']"

    post switch_workspace_path(other)
    assert_redirected_to root_path
    get root_path
    assert_select ".workspaces__item--current[title='Second Co']"
    assert_select ".project-card h2", count: 0 # Second Co has no projects: nothing of Orbit leaks across
  end

  test "you cannot switch into a workspace you do not belong to" do
    stranger = Workspace.create!(name: "Not Mine")
    sign_in_as users(:ines)
    post switch_workspace_path(stranger)
    assert_response :not_found
    get root_path
    assert_select ".workspaces__item--current[title='Orbit Labs']"
  end

  # ---- suspension & missing workspace -------------------------------------------------------
  test "members of a suspended workspace see why and cannot use the app" do
    @orbit.suspend!("Invoice overdue")
    sign_in_as users(:jonas)

    get root_path
    assert_response :forbidden
    assert_select "h1", "Orbit Labs is on hold"
    assert_select ".sign-in__heading p", /Invoice overdue/

    get project_topics_path(projects(:apollo))
    assert_response :forbidden
  end

  test "a suspended tenant can still sign out" do
    @orbit.suspend!
    sign_in_as users(:jonas)
    delete sign_out_path
    assert_redirected_to sign_in_path
  end

  test "someone suspended in one workspace can open another" do
    other = Workspace.create!(name: "Second Co")
    other.memberships.create!(user: users(:jonas), role: "member")
    @orbit.suspend!
    sign_in_as users(:jonas)
    get root_path # lands in the active workspace automatically
    assert_response :success
    assert_select ".workspaces__item--current[title='Second Co']"
  end

  test "reactivating restores access" do
    @orbit.suspend!
    @orbit.reactivate!
    sign_in_as users(:jonas)
    get root_path
    assert_response :success
  end

  test "signed-in people without any workspace are told to ask for an invitation" do
    loner = User.create!(name: "Loner", email: "loner@nowhere.io")
    loner.identities.create!(provider: "google", uid: "loner", email: loner.email)
    sign_in_as loner
    get root_path
    assert_response :forbidden
    assert_select "h1", "You're not in a workspace yet"
  end

  test "platform staff without a workspace are sent to the backoffice" do
    sign_in_as users(:staff)
    get root_path
    assert_redirected_to backoffice_root_path
  end
end

class TrialBannerTest < ActionDispatch::IntegrationTest
  test "admins on a trial see how long is left" do
    workspaces(:orbit).update!(plan: "trial", trial_ends_at: 5.days.from_now)
    sign_in_as users(:ines)
    get root_path
    assert_select ".trial-banner", /ends in 5 days/
  end

  test "an expired trial says so" do
    workspaces(:orbit).update!(plan: "trial", trial_ends_at: 1.day.ago)
    sign_in_as users(:ines)
    get root_path
    assert_select ".trial-banner--over", /trial has ended/
  end

  test "regular members and paying tenants see no banner" do
    workspaces(:orbit).update!(plan: "trial", trial_ends_at: 5.days.from_now)
    sign_in_as users(:jonas)
    get root_path
    assert_select ".trial-banner", count: 0

    sign_out
    workspaces(:orbit).update!(plan: "team")
    sign_in_as users(:ines)
    get root_path
    assert_select ".trial-banner", count: 0
  end
end
