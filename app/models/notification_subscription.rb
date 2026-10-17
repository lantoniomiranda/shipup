class NotificationSubscription < ApplicationRecord
  KINDS = %w[mention_or_reply new_topic similar_topic task_assigned subtask_unlocked meeting_invite].freeze

  # What a user gets before ever touching the settings (matches the design).
  DEFAULTS = { "mention_or_reply" => true, "new_topic" => false, "similar_topic" => false,
               "task_assigned" => true, "subtask_unlocked" => true, "meeting_invite" => true }.freeze

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }, uniqueness: { scope: :user_id }
end
