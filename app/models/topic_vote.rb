class TopicVote < ApplicationRecord
  belongs_to :topic
  belongs_to :user

  validates :value, inclusion: { in: [ -1, 1 ] }
  validates :user_id, uniqueness: { scope: :topic_id }
end
