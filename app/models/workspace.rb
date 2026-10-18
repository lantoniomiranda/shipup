# The tenant: a company's ohship. Everything else hangs off a workspace.
class Workspace < ApplicationRecord
  MEETING_PROVIDERS = %w[zoom google_meet].freeze
  STATUSES = %w[active suspended].freeze
  PLANS = %w[trial starter team enterprise].freeze
  TRIAL_DAYS = 14

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :projects, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_many :integration_connections, dependent: :destroy
  has_many :invitations, dependent: :destroy

  enum :status, STATUSES.index_with(&:itself), default: "active", validate: true
  enum :plan, PLANS.index_with(&:itself), default: "trial", validate: true, prefix: true

  scope :search, ->(term) { where("workspaces.name ILIKE :q OR workspaces.slug ILIKE :q", q: "%#{sanitize_sql_like(term)}%") if term.present? }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/ }
  validates :email_domain, uniqueness: true, allow_nil: true
  validates :meeting_provider, inclusion: { in: MEETING_PROVIDERS }, allow_nil: true

  before_validation { self.slug = name.to_s.parameterize if slug.blank? }

  # The active workspace whose company email domain lets this person join on their own, if any.
  def self.joinable_for(email)
    domain = email.to_s.split("@").last.to_s.downcase
    active.find_by(email_domain: domain, allow_domain_join: true) if domain.present?
  end

  # Creates a tenant and invites its first admin. Used by the backoffice.
  # Extra attributes (slug, email_domain, allow_domain_join) go straight onto the workspace.
  def self.provision!(name:, admin_email:, plan: "trial", seats_limit: nil, invited_by: nil, trial_days: TRIAL_DAYS, **attributes)
    transaction do
      workspace = create!(name: name, plan: plan, seats_limit: seats_limit, trial_ends_at: (Time.current + trial_days.days if plan == "trial"), **attributes)
      workspace.invitations.create!(email: admin_email, role: "admin", invited_by: invited_by)
      workspace
    end
  end

  def seats_used = memberships.count + invitations.pending.count
  def seat_available? = seats_limit.nil? || seats_used < seats_limit
  def seats_left = seats_limit && [ seats_limit - seats_used, 0 ].max

  def trial_expired? = plan_trial? && trial_ends_at.present? && trial_ends_at < Time.current

  def suspend!(reason = nil)
    update!(status: "suspended", suspended_at: Time.current, suspended_reason: reason.presence)
  end

  def reactivate!
    update!(status: "active", suspended_at: nil, suspended_reason: nil)
  end

  # Up to `limit` distinct teammate time zones, the current user's first, for the top-bar clocks.
  def clock_zones(for_user:, limit: 4)
    zones = users.distinct.pluck(:time_zone)
    ([ for_user.time_zone ] + zones.sort).uniq.first(limit)
  end

  def connection_for(provider)
    integration_connections.find_by(provider: provider)
  end
end
