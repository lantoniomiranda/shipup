require "test_helper"

class ProjectMembersTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    sign_in_as users(:ines) # project admin of Apollo and superadmin
  end

  test "lists the people on the project" do
    get project_members_path(@project)
    assert_response :success
    assert_select ".tab--active", /People/
    assert_select "tbody tr", 2
    assert_select ".invite-bar"
  end

  test "plain members see the list but no controls" do
    sign_out
    sign_in_as users(:jonas)
    get project_members_path(@project)
    assert_response :success
    assert_select ".invite-bar", count: 0
    assert_select "button", text: /Remove/, count: 0
    patch project_member_path(@project, @project.project_memberships.first), params: { project_membership: { role: "admin" } }
    assert_response :forbidden
  end

  test "inviting a new email creates a pending invitation and sends the mail" do
    assert_difference "Invitation.pending.count", 1 do
      assert_enqueued_emails 1 do
        post project_invitations_path(@project), params: { invitation: { email: " New@Person.io ", role: "member" } }
      end
    end
    assert_redirected_to project_members_path(@project)
    invitation = Invitation.pending.find_by!(email: "new@person.io")
    assert_equal @project, invitation.project
    assert_equal users(:ines), invitation.invited_by
  end

  test "inviting someone who already has an account adds them straight away" do
    outsider = User.create!(name: "Old Timer", email: "old@timer.io")
    assert_difference "ProjectMembership.count", 1 do
      post project_invitations_path(@project), params: { invitation: { email: outsider.email, role: "admin" } }
    end
    assert_equal "admin", @project.project_memberships.find_by!(user: outsider).role
    assert_empty Invitation.pending.where(email: outsider.email)
  end

  test "people already on the project cannot be invited again" do
    assert_no_difference "Invitation.count" do
      post project_invitations_path(@project), params: { invitation: { email: users(:jonas).email } }
    end
    follow_redirect!
    assert_select ".toast", /already on this project/
  end

  test "an invitation can be re-sent and revoked" do
    invitation = @project.invitations.create!(email: "later@person.io")
    assert_enqueued_emails 1 do
      post resend_project_invitation_path(@project, invitation)
    end
    delete project_invitation_path(@project, invitation)
    assert_not invitation.reload.pending?
  end

  test "changing a role and removing a person" do
    membership = @project.project_memberships.find_by!(user: users(:jonas))
    patch project_member_path(@project, membership), params: { project_membership: { role: "admin" } }
    assert membership.reload.admin?

    assert_difference "ProjectMembership.count", -1 do
      delete project_member_path(@project, membership)
    end
    assert User.exists?(users(:jonas).id), "the account stays"
  end

  test "nobody can remove themselves or set a role that does not exist" do
    own = @project.project_memberships.find_by!(user: users(:ines))
    assert_no_difference "ProjectMembership.count" do
      delete project_member_path(@project, own)
    end
    patch project_member_path(@project, own), params: { project_membership: { role: "emperor" } }
    assert own.reload.admin?
  end

  test "a removed person loses access to the project" do
    delete project_member_path(@project, @project.project_memberships.find_by!(user: users(:jonas)))
    sign_out
    sign_in_as users(:jonas)
    get project_topics_path(@project)
    assert_response :not_found
  end
end
