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

  def provider_config
    Integrations.provider(provider)
  end

  # An access token that is safe to use right now, refreshing it first when it is about to lapse.
  def fresh_access_token!(redirect_uri: nil)
    refresh!(redirect_uri: redirect_uri) if expired?(now: 1.minute.from_now) && refresh_token.present?
    access_token
  end

  def refresh!(redirect_uri: nil)
    tokens = Integrations::OauthClient.new(provider_config, redirect_uri: redirect_uri).refresh(refresh_token: refresh_token)
    update!(access_token: tokens.access_token, refresh_token: tokens.refresh_token, expires_at: tokens.expires_at)
  end
end
