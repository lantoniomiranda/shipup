# Sign-in from an OmniAuth auth hash. ohship is invite-only: an unknown email can only get in with
# a pending invitation, through a workspace that allows joining by company email domain, or as
# platform staff (PLATFORM_ADMIN_EMAILS).
module User::Omniauth
  extend ActiveSupport::Concern

  class NotInvited < StandardError; end

  class_methods do
    def from_omniauth(auth)
      provider = Identity::STRATEGIES.fetch(auth.provider)
      email = auth.info.email.to_s.strip.downcase
      raise ArgumentError, "provider returned no email" if email.blank?

      transaction do
        user = Identity.find_by(provider: provider, uid: auth.uid)&.user || find_by(email: email) || sign_up!(auth, email)
        user.identities.find_or_create_by!(provider: provider, uid: auth.uid) { |identity| identity.email = email }
        join_instance!(user) if platform_admin_email?(email)
        Invitation.accept_all_for(user)
        user
      end
    end

    private

    # Superadmins always belong to the deployment's own workspace, so sign-in lands on the dashboard.
    def join_instance!(user)
      user.update!(platform_admin: true) unless user.platform_admin?
      Workspace.instance.memberships.find_or_create_by!(user: user) { |membership| membership.role = "admin" }
    end

    def sign_up!(auth, email)
      invited = Invitation.pending.exists?(email: email)
      domain_workspace = Workspace.joinable_for(email) unless invited
      domain_workspace = nil if domain_workspace && !domain_workspace.seat_available?
      raise NotInvited, "#{email} has no invitation" unless invited || domain_workspace || platform_admin_email?(email)

      create!(name: auth.info.name.presence || email.split("@").first.titleize, email: email).tap do |user|
        domain_workspace&.memberships&.create!(user: user, role: "member")
      end
    end
  end
end
