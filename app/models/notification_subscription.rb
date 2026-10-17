class NotificationSubscription < ApplicationRecord
  KINDS = %w[mention_or_reply new_topic similar_topic task_assigned subtask_unlocked meeting_invite].freeze

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }, uniqueness: { scope: :user_id }
end
