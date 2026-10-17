class Task < ApplicationRecord
  # Board columns, left to right.
  STATUSES = %w[todo in_progress testing ready_to_deploy done].freeze

  belongs_to :project
  belongs_to :sprint, optional: true
  belongs_to :topic, optional: true
  belongs_to :chain, optional: true
  belongs_to :client, optional: true
  belongs_to :assignee, class_name: "User", optional: true
  belongs_to :creator, class_name: "User"
  has_many :task_labels, dependent: :destroy
  has_many :labels, through: :task_labels
  has_many :time_entries, dependent: :destroy
  has_many :task_pull_requests, dependent: :destroy
  has_many :pull_requests, through: :task_pull_requests

  enum :status, STATUSES.index_with(&:itself), default: "todo", validate: true

  validates :title, presence: true
  validates :number, uniqueness: { scope: :project_id }
  validates :estimate_minutes, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :chain_position, presence: true, if: :chain_id?

  before_validation :assign_number, on: :create
  before_save :stamp_completion, if: :status_changed?

  MINUTES_PER_DAY = 8 * 60

  # Estimates are stored in minutes but entered in working days.
  def estimate_days
    estimate_minutes && estimate_minutes.to_f / MINUTES_PER_DAY
  end

  def estimate_days=(days)
    self.estimate_minutes = days.present? ? (days.to_f * MINUTES_PER_DAY).round : nil
  end

  # "APO-97"
  def key
    "#{project.key}-#{number}"
  end

  def logged_minutes
    time_entries.sum("EXTRACT(EPOCH FROM (COALESCE(ended_at, NOW()) - started_at)) / 60").to_i
  end

  def overdue?(today: Date.current)
    due_on.present? && due_on < today && !done?
  end

  # The next step in the chain, if this task belongs to one.
  def next_in_chain
    chain&.tasks&.find_by("chain_position > ?", chain_position)
  end

  private

  def assign_number
    self.number ||= project.next_task_number!
  end

  def stamp_completion
    self.completed_at = done? ? Time.current : nil
  end
end
