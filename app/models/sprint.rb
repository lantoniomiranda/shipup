class Sprint < ApplicationRecord
  STATES = %w[planned active completed].freeze

  belongs_to :project
  has_many :tasks, dependent: :nullify

  enum :state, STATES.index_with(&:itself), default: "planned", validate: true

  scope :upcoming, -> { planned.order(:starts_on) }

  validates :number, presence: true, uniqueness: { scope: :project_id }
  validates :starts_on, :ends_on, presence: true
  validate :ends_after_start

  def name
    "Sprint #{number}"
  end

  # The next free number and a default two-week window after the latest sprint.
  def self.next_for(project, today: Date.current)
    last = project.sprints.order(:number).last
    starts_on = [ (last&.ends_on || today - 1) + 1, today ].max
    project.sprints.new(number: (last&.number || 0) + 1, starts_on: starts_on, ends_on: starts_on + 13)
  end

  # Makes this the project's only active sprint. The previous one is completed; unfinished
  # tasks move here when `carry_over` is true, otherwise they go back to the backlog.
  def start!(carry_over: true)
    transaction do
      previous = project.sprints.active.where.not(id: id).first
      previous&.complete!(carry_over_to: carry_over ? self : nil)
      update!(state: "active")
    end
  end

  # Closes the sprint. Unfinished tasks move to `carry_over_to`, or back to the backlog when nil.
  def complete!(carry_over_to: nil)
    transaction do
      tasks.where.not(status: "done").update_all(sprint_id: carry_over_to&.id)
      update!(state: "completed", completed_at: Time.current)
    end
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
