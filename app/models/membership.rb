class Membership < ApplicationRecord
  include RoleBased
  role_based %w[admin manager member]

  belongs_to :workspace
  belongs_to :user

  validates :user_id, uniqueness: { scope: :workspace_id }
end
