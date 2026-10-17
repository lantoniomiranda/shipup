class Sprint < ApplicationRecord
  belongs_to :project
  has_many :tasks, dependent: :nullify

  validates :number, presence: true, uniqueness: { scope: :project_id }
  validates :starts_on, :ends_on, presence: true
  validate :ends_after_start

  def name
    "Sprint #{number}"
  end

  def days_left(from: Date.current)
    [ (ends_on - from).to_i + 1, 0 ].max
  end

  # Share of estimated work that is done, as a 0-100 integer ("68% XP").
  def progress_percent
    total = tasks.sum(:estimate_minutes)
    return 0 if total.zero?

    (tasks.done.sum(:estimate_minutes) * 100.0 / total).round
  end

  private

  def ends_after_start
    errors.add(:ends_on, "must be on or after the start date") if starts_on && ends_on && ends_on < starts_on
  end
end
