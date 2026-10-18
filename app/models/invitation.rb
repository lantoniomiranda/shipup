# An invitation to one project. Sign-in is OAuth-only, so "accepting" just means signing in with
# the invited email: the invitation is consumed the first time that user appears (or at once, if
# they already have an account).
class Invitation < ApplicationRecord
  include RoleBased
  role_based %w[admin member], default: "member"

  belongs_to :project
  belongs_to :invited_by, class_name: "User", optional: true

  has_secure_token :token

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :not_already_a_member, on: :create

  scope :pending, -> { where(accepted_at: nil, revoked_at: nil) }

  def pending? = accepted_at.nil? && revoked_at.nil?

  # Gives the user their place on the project and closes the invitation.
  def accept!(user)
    transaction do
      project.project_memberships.find_or_create_by!(user: user) { |membership| membership.role = role }
      update!(accepted_at: Time.current)
    end
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  # Accepts every pending invitation addressed to this user's email.
  def self.accept_all_for(user)
    pending.where(email: user.email).find_each { |invitation| invitation.accept!(user) }
  end

  private

  def not_already_a_member
    errors.add(:email, I18n.t("model_errors.already_member")) if project && email && project.members.exists?(email: email)
  end
end
