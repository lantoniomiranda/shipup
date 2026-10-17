class TimeOffAllowance < ApplicationRecord
  # Days per year when nothing has been configured for a user.
  DEFAULT_DAYS = { "vacation" => 22, "sick" => 5, "family" => 3 }.freeze

  belongs_to :user

  validates :kind, inclusion: { in: TimeOffRequest::KINDS }, uniqueness: { scope: %i[user_id year] }
  validates :days, numericality: { greater_than_or_equal_to: 0 }
end
