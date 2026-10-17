class TimeOffRequest < ApplicationRecord
  KINDS = %w[vacation sick family].freeze
  STATUSES = %w[pending approved declined].freeze

  belongs_to :user
  belongs_to :approver, class_name: "User", optional: true

  enum :kind, KINDS.index_with(&:itself), validate: true
  enum :status, STATUSES.index_with(&:itself), default: "pending", validate: true

  validates :starts_on, :ends_on, presence: true
  validate :ends_after_start

  before_validation :count_working_days

  scope :overlapping, ->(range) { where("starts_on <= ? AND ends_on >= ?", range.end, range.begin) }

  def decide!(by:, approve:)
    update!(status: approve ? "approved" : "declined", approver: by, decided_at: Time.current)
  end

  private

  def count_working_days
    return unless starts_on && ends_on

    self.working_days = (starts_on..ends_on).count { |day| !day.saturday? && !day.sunday? }
  end

  def ends_after_start
    errors.add(:ends_on, "must be on or after the start date") if starts_on && ends_on && ends_on < starts_on
  end
end
