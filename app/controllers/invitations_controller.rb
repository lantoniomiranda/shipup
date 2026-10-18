# Admins and project admins invite people to a project by email. Someone who already has an
# account is added straight away; everyone else gets in the first time they sign in with that email.
class InvitationsController < ApplicationController
  include ProjectScoped
  before_action :require_project_admin
  before_action :set_invitation, only: %i[destroy resend]

  def create
    invitation = @project.invitations.build(params.expect(invitation: %i[email role]).merge(invited_by: Current.user))
    if invitation.save
      existing = User.find_by(email: invitation.email)
      invitation.accept!(existing) if existing
      InvitationMailer.invite(invitation).deliver_later
      notice = existing ? t("people.added_member", name: existing.short_name, project: @project.name) : t("people.sent_invite", email: invitation.email)
      redirect_to project_members_path(@project), notice: notice, status: :see_other
    else
      redirect_to project_members_path(@project), alert: invitation.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def resend
    InvitationMailer.invite(@invitation).deliver_later
    redirect_to project_members_path(@project), notice: t("people.resent", email: @invitation.email), status: :see_other
  end

  def destroy
    @invitation.revoke!
    redirect_to project_members_path(@project), notice: t("people.revoked", email: @invitation.email), status: :see_other
  end

  private

  def set_invitation
    @invitation = @project.invitations.pending.find(params[:id])
  end
end
