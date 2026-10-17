# A workspace's authorised link to a third party (Zoom, Google Meet, GitHub).
class IntegrationConnection < ApplicationRecord
  PROVIDERS = %w[zoom google_meet github].freeze

  belongs_to :workspace
  belongs_to :connected_by, class_name: "User"
  has_many :github_repositories, dependent: :destroy

  encrypts :access_token, :refresh_token

  validates :provider, inclusion: { in: PROVIDERS }, uniqueness: { scope: :workspace_id }
  validates :external_account, presence: true

  def expired?(now: Time.current)
    expires_at.present? && expires_at <= now
  end
end
