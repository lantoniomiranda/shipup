class TaskMessage < ApplicationRecord
  include ChatMessage
  chat_message thread: :task

  belongs_to :task
end
