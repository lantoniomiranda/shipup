# An external OAuth account (Google or Microsoft) linked to a user.
class Identity < ApplicationRecord
  PROVIDERS = %w[google microsoft].freeze

  belongs_to :user

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :provider, inclusion: { in: PROVIDERS }
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :email, presence: true
end
