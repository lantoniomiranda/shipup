# Membership-style records whose `role` is one of ROLES. Pass the allowed
# roles, ordered from most to least privileged: `role_based %w[admin manager member]`.
module RoleBased
  extend ActiveSupport::Concern

  class_methods do
    def role_based(roles, default: roles.last)
      enum :role, roles.index_with(&:itself), default: default, validate: true
    end
  end
end
