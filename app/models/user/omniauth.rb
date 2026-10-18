# Sign-in from an OmniAuth auth hash. ShipUp is invite-only: an unknown email can only get in with
# a pending project invitation, or when it is a superadmin email (SUPERADMIN_EMAILS: how the first person gets in).
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
        Invitation.accept_all_for(user)
        user
      end
    end

    private

    def sign_up!(auth, email)
      raise NotInvited, "#{email} has no invitation" unless Invitation.pending.exists?(email: email) || superadmin_email?(email)

      create!(name: auth.info.name.presence || email.split("@").first.titleize, email: email)
    end
  end
end
