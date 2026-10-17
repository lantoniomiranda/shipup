# The tenant: a company's Nook. Everything else hangs off a workspace.
class Workspace < ApplicationRecord
  MEETING_PROVIDERS = %w[zoom google_meet].freeze

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :projects, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_many :integration_connections, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :email_domain, uniqueness: true, allow_nil: true
  validates :meeting_provider, inclusion: { in: MEETING_PROVIDERS }, allow_nil: true

  before_validation { self.slug = name.to_s.parameterize if slug.blank? }

  # Free mail providers are never shared: each such person gets their own workspace.
  PERSONAL_DOMAINS = %w[gmail.com googlemail.com outlook.com hotmail.com live.com yahoo.com icloud.com proton.me].freeze

  # The workspace a new sign-up with this email should join, creating it on first use.
  def self.for_signup(email)
    domain = email.split("@").last
    return create!(name: "#{email.split("@").first.titleize}'s workspace", slug: SecureRandom.alphanumeric(8).downcase) if PERSONAL_DOMAINS.include?(domain)

    create_with(name: "#{domain.split(".").first.titleize} workspace").find_or_create_by!(email_domain: domain)
  end

  def connection_for(provider)
    integration_connections.find_by(provider: provider)
  end
end
