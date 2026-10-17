class User < ApplicationRecord
  include Omniauth

  AVATAR_ICONS = %w[cat bird rocket coffee flower ghost moon fish leaf telescope].freeze

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
