# Sign-in/sign-up from an OmniAuth auth hash. Finds the user by linked identity,
# else by email (linking the new provider), else creates the account and its workspace membership.
module User::Omniauth
  extend ActiveSupport::Concern

  class_methods do
    def from_omniauth(auth)
      provider = Identity::STRATEGIES.fetch(auth.provider)
      email = auth.info.email.to_s.strip.downcase
      raise ArgumentError, "provider returned no email" if email.blank?

      transaction do
        identity = Identity.find_by(provider: provider, uid: auth.uid)
        next identity.user if identity

        user = find_by(email: email) || sign_up!(name: auth.info.name.presence || email.split("@").first.titleize, email: email)
        user.identities.create!(provider: provider, uid: auth.uid, email: email)
        user
      end
    end

    private

    # The first person into a workspace administers it.
    def sign_up!(name:, email:)
      create!(name: name, email: email).tap do |user|
        workspace = Workspace.for_signup(email)
        user.memberships.create!(workspace: workspace, role: workspace.memberships.exists? ? "member" : "admin")
      end
    end
  end
end
