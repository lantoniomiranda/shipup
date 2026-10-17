class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @workspace = invitation.workspace
    @inviter = invitation.invited_by
    mail to: invitation.email, subject: "You're invited to #{@workspace.name} on #{Rails.configuration.x.product_name}"
  end
end
