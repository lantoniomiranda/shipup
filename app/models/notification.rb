class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :subject, polymorphic: true

  validates :kind, inclusion: { in: NotificationSubscription::KINDS }

  scope :unread, -> { where(read_at: nil) }

  def read!
    update!(read_at: Time.current) unless read_at
  end
end
