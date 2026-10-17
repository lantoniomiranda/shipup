class Backoffice::InvitationsController < Backoffice::BaseController
  before_action :set_workspace

  def create
    invitation = @workspace.invitations.build(params.expect(invitation: %i[email role]).merge(invited_by: Current.user))
    if invitation.save
      InvitationMailer.invite(invitation).deliver_later
      redirect_to backoffice_tenant_path(@workspace), notice: "Invitation sent to #{invitation.email}.", status: :see_other
    else
      redirect_to backoffice_tenant_path(@workspace), alert: invitation.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def resend
    invitation = @workspace.invitations.pending.find(params[:id])
    InvitationMailer.invite(invitation).deliver_later
    redirect_to backoffice_tenant_path(@workspace), notice: "Invitation re-sent to #{invitation.email}.", status: :see_other
  end

  def destroy
    invitation = @workspace.invitations.pending.find(params[:id])
    invitation.revoke!
    redirect_to backoffice_tenant_path(@workspace), notice: "Invitation for #{invitation.email} revoked.", status: :see_other
  end

  private

  def set_workspace
    @workspace = Workspace.find(params[:tenant_id])
  end
end
