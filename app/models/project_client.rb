class ProjectClient < ApplicationRecord
  STATUSES = %w[invite_pending active].freeze

  belongs_to :project
  belongs_to :client

  enum :status, STATUSES.index_with(&:itself), default: "invite_pending", validate: true

  validates :client_id, uniqueness: { scope: :project_id }
end
