class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @project = invitation.project
    @inviter = invitation.invited_by
    mail to: invitation.email, subject: I18n.t("mailer.subject", project: @project.name, product: Rails.configuration.x.product_name)
  end
end
