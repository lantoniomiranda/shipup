class TopicMessage < ApplicationRecord
  include ChatMessage
  chat_message thread: :topic

  belongs_to :topic, counter_cache: :messages_count, touch: :last_activity_at
end
