class PullRequest < ApplicationRecord
  STATES = %w[open closed merged].freeze

  belongs_to :github_repository
  has_many :task_pull_requests, dependent: :destroy
  has_many :tasks, through: :task_pull_requests

  enum :state, STATES.index_with(&:itself), default: "open", validate: true

  validates :number, presence: true, uniqueness: { scope: :github_repository_id }
  validates :title, :url, presence: true
end
