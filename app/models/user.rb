class User < ApplicationRecord
  include Omniauth

  AVATAR_ICONS = %w[cat bird rocket coffee flower-2 ghost moon fish leaf telescope].freeze

  has_many :invitations_sent, class_name: "Invitation", foreign_key: :invited_by_id, inverse_of: :invited_by, dependent: :nullify
  has_many :identities, dependent: :destroy
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships
  has_many :project_memberships, dependent: :destroy
  has_many :projects, through: :project_memberships
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assignee_id, inverse_of: :assignee, dependent: :nullify
  has_many :time_entries, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :time_off_requests, dependent: :destroy
  has_many :time_off_allowances, dependent: :destroy
  has_many :notification_subscriptions, dependent: :destroy
  has_one :preference, class_name: "UserPreference", dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :avatar_icon, inclusion: { in: AVATAR_ICONS }
  validates :avatar_color, inclusion: { in: Hued::HUES }
  validates :time_zone, inclusion: { in: TZInfo::Timezone.all_identifiers }

  after_create :build_default_preference

  # Always usable, even before a preferences row has been saved.
  def preference
    super || build_preference
  end

  def initials
    name.split.map { |part| part[0] }.first(2).join.upcase
  end

  # "Sofia Reyes" -> "Sofia R."
  def short_name
    first, last = name.split
    last ? "#{first} #{last[0]}." : first
  end

  def first_name
    name.split.first
  end

  # "Europe/Lisbon" -> "Lisbon"
  def city
    time_zone.split("/").last.tr("_", " ")
  end

  def greeting(now: Time.current)
    hour = now.in_time_zone(time_zone).hour
    period = hour < 12 ? "morning" : (hour < 18 ? "afternoon" : "evening")
    "Good #{period}, #{first_name}."
  end

  # Is this kind of notification switched on? Unset kinds fall back to NotificationSubscription::DEFAULTS.
  def subscribed_to?(kind)
    subscription = notification_subscriptions.find { |row| row.kind == kind }
    subscription ? subscription.enabled : NotificationSubscription::DEFAULTS.fetch(kind)
  end

  # Takes { "mention_or_reply" => "1", ... } from the account form.
  def update_notification_subscriptions(settings)
    settings.slice(*NotificationSubscription::KINDS).each do |kind, value|
      notification_subscriptions.find_or_initialize_by(kind: kind).update!(enabled: ActiveModel::Type::Boolean.new.cast(value))
    end
  end

  # Admins and managers can approve other people's time off.
  def can_approve_time_off_for?(other, workspace)
    self != other && %w[admin manager].include?(role_in(workspace))
  end

  # Platform staff (ShipUp itself, not a customer). Listed in PLATFORM_ADMIN_EMAILS.
  def self.platform_admin_email?(email)
    ENV["PLATFORM_ADMIN_EMAILS"].to_s.split(",").map { |address| address.strip.downcase }.include?(email.to_s.strip.downcase)
  end

  def role_in(workspace)
    memberships.find_by(workspace: workspace)&.role
  end

  def running_time_entry
    time_entries.find_by(ended_at: nil)
  end

  private

  def build_default_preference
    create_preference!
  end
end
