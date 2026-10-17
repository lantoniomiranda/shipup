class ProjectMembership < ApplicationRecord
  include RoleBased
  role_based %w[manager member]

  belongs_to :project
  belongs_to :user

  validates :user_id, uniqueness: { scope: :project_id }
end
