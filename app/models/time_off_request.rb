class TimeOffRequest < ApplicationRecord
  KINDS = %w[vacation sick family].freeze
  STATUSES = %w[pending approved declined].freeze

  belongs_to :user
  belongs_to :approver, class_name: "User", optional: true

  enum :kind, KINDS.index_with(&:itself), validate: true
  enum :status, STATUSES.index_with(&:itself), default: "pending", validate: true

  validates :starts_on, :ends_on, presence: true
  validate :ends_after_start
  validate :within_balance, on: :create

  # Validations need the count; before_save keeps it right when validations are skipped (imports, seeds).
  before_validation :count_working_days
  before_save :count_working_days

  scope :counting_against_allowance, -> { where(status: %w[pending approved]) }
  scope :overlapping, ->(range) { where("starts_on <= ? AND ends_on >= ?", range.end, range.begin) }

  # Days the user can still take (allowance minus approved and waiting requests in that year).
  Balance = Data.define(:allowance, :used) do
    def left = allowance - used
  end

  def self.balance_for(user, kind, year: Date.current.year)
    allowance = user.time_off_allowances.find_by(kind: kind, year: year)&.days || TimeOffAllowance::DEFAULT_DAYS.fetch(kind)
    used = user.time_off_requests.counting_against_allowance.where(kind: kind).where(starts_on: Date.new(year)..Date.new(year, 12, 31)).sum(:working_days)
    Balance.new(allowance: allowance, used: used)
  end

  def decide!(by:, approve:)
    update!(status: approve ? "approved" : "declined", approver: by, decided_at: Time.current)
  end

  private

  def count_working_days
    return unless starts_on && ends_on

    self.working_days = (starts_on..ends_on).count { |day| !day.saturday? && !day.sunday? }
  end

  def within_balance
    return unless user && kind && starts_on && ends_on

    left = self.class.balance_for(user, kind, year: starts_on.year).left
    errors.add(:base, "That's more than the #{left} #{kind} days you have left") if working_days.to_i > left
  end

  def ends_after_start
    errors.add(:ends_on, "must be on or after the start date") if starts_on && ends_on && ends_on < starts_on
  end
end
