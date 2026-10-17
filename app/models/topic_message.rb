class TopicMessage < ApplicationRecord
  belongs_to :topic, counter_cache: :messages_count, touch: :last_activity_at
  belongs_to :author, class_name: "User"

  validates :body, presence: true
end
