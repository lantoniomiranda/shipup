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
  validates :meeting_provider, inclusion: { in: MEETING_PROVIDERS }, allow_nil: true

  before_validation { self.slug = name.to_s.parameterize if slug.blank? }

  def connection_for(provider)
    integration_connections.find_by(provider: provider)
  end
end
