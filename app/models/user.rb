class User < ApplicationRecord
  include Omniauth

  AVATAR_ICONS = %w[cat bird rocket coffee flower-2 ghost moon fish leaf telescope].freeze

  has_many :invitations_sent, class_name: "Invitation", foreign_key: :invited_by_id, inverse_of: :invited_by, dependent: :nullify
  has_many :identities, dependent: :destroy
  has_many :sessions, dependent: :destroy
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
    I18n.t("greetings.#{period}", name: first_name)
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

  # Superadmins and project admins can approve other people's time off.
  def approver? = superadmin? || project_memberships.admin.exists?

  def can_approve_time_off_for?(other)
    self != other && approver?
  end

  # Superadmins are the emails in SUPERADMIN_EMAILS (config.x.superadmin_emails): nothing is stored, so
  # taking an email out of the list revokes the access on the next request.
  def self.superadmin_email?(email)
    Rails.configuration.x.superadmin_emails.include?(email.to_s.strip.downcase)
  end

  def superadmin? = self.class.superadmin_email?(email)

  # Everyone this person works with: superadmins see the whole company, others the people on their projects.
  def teammates
    return User.all if superadmin?

    User.where(id: ProjectMembership.where(project_id: project_memberships.select(:project_id)).select(:user_id)).or(User.where(id: id))
  end

  # Up to `limit` distinct teammate time zones, this user's own first, for the top-bar clocks.
  def clock_zones(limit: 4)
    ([ time_zone ] + teammates.distinct.pluck(:time_zone).sort).uniq.first(limit)
  end

  def running_time_entry
    time_entries.find_by(ended_at: nil)
  end

  private

  def build_default_preference
    create_preference!
  end
end
