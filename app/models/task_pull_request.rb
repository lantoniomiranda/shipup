class TaskPullRequest < ApplicationRecord
  belongs_to :task
  belongs_to :pull_request

  validates :pull_request_id, uniqueness: { scope: :task_id }
end
