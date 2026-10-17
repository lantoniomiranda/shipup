# An invitation to join a workspace. Sign-in is OAuth-only, so "accepting" just means signing in
# with the invited email: the invitation is consumed the first time that user appears.
class Invitation < ApplicationRecord
  include RoleBased
  role_based %w[admin manager member], default: "member"

  belongs_to :workspace
  belongs_to :invited_by, class_name: "User", optional: true

  has_secure_token :token

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :not_already_a_member, on: :create
  validate :seat_available, on: :create

  scope :pending, -> { where(accepted_at: nil, revoked_at: nil) }

  def pending? = accepted_at.nil? && revoked_at.nil?

  # Gives the user their membership and closes the invitation.
  def accept!(user)
    transaction do
      workspace.memberships.find_or_create_by!(user: user) { |membership| membership.role = role }
      update!(accepted_at: Time.current)
    end
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  # Accepts every pending invitation addressed to this user's email (a person can join several tenants).
  def self.accept_all_for(user)
    pending.where(email: user.email).includes(:workspace).find_each { |invitation| invitation.accept!(user) if invitation.workspace.active? }
  end

  private

  def not_already_a_member
    errors.add(:email, "is already a member of this workspace") if workspace && email && workspace.users.exists?(email: email)
  end

  def seat_available
    errors.add(:base, "No seats left on this plan") if workspace && !workspace.seat_available?
  end
end
