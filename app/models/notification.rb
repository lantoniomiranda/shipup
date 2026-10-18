# Something that happened that a person should hear about (a reply, an assignment, an invite…).
# Create them with Notification.notify: it respects each person's notification settings and never
# notifies someone about their own action.
class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :subject, polymorphic: true

  validates :kind, inclusion: { in: NotificationSubscription::KINDS }

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # Returns the notification, or nil when the person muted that kind or caused the event themselves.
  def self.notify(user:, kind:, subject:, actor: Current.user)
    return if user.nil? || user == actor || !user.subscribed_to?(kind.to_s)

    create!(user: user, kind: kind, subject: subject, actor: actor)
  end

  def self.mark_all_read(user)
    user.notifications.unread.update_all(read_at: Time.current)
  end

  def read? = read_at.present?

  def read!
    update!(read_at: Time.current) unless read_at
  end
end
