# Workspace admins invite their own people (platform staff do the same from the backoffice).
class InvitationsController < ApplicationController
  before_action :require_workspace_admin
  before_action :set_invitation, only: %i[destroy resend]

  def create
    invitation = Current.workspace.invitations.build(params.expect(invitation: %i[email role]).merge(invited_by: Current.user))
    if invitation.save
      InvitationMailer.invite(invitation).deliver_later
      redirect_to memberships_path, notice: "Invitation sent to #{invitation.email}.", status: :see_other
    else
      redirect_to memberships_path, alert: invitation.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def resend
    InvitationMailer.invite(@invitation).deliver_later
    redirect_to memberships_path, notice: "Invitation re-sent to #{@invitation.email}.", status: :see_other
  end

  def destroy
    @invitation.revoke!
    redirect_to memberships_path, notice: "Invitation for #{@invitation.email} revoked.", status: :see_other
  end

  private

  def set_invitation
    @invitation = Current.workspace.invitations.pending.find(params[:id])
  end
end
