class TimeOffAllowance < ApplicationRecord
  belongs_to :user

  validates :kind, inclusion: { in: TimeOffRequest::KINDS }, uniqueness: { scope: %i[user_id year] }
  validates :days, numericality: { greater_than_or_equal_to: 0 }
end
