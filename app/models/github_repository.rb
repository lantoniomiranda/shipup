class GithubRepository < ApplicationRecord
  belongs_to :project
  belongs_to :integration_connection
  has_many :pull_requests, dependent: :destroy

  validates :external_id, presence: true, uniqueness: { scope: :project_id }
  validates :full_name, presence: true
end
