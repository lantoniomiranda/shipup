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
  has_many :messages, class_name: "TaskMessage", dependent: :destroy
  has_many :time_entries, dependent: :destroy
  has_many :task_pull_requests, dependent: :destroy
  has_many :pull_requests, through: :task_pull_requests

  enum :status, STATUSES.index_with(&:itself), default: "todo", validate: true

  # Archived tasks are soft-deleted: invisible everywhere (boards, lists, counts, search) unless
  # asked for with `Task.archived`.
  default_scope { where(archived_at: nil) }
  scope :archived, -> { unscope(where: :archived_at).where.not(archived_at: nil) }

  validates :title, presence: true
  validates :number, uniqueness: { scope: :project_id }
  validates :estimate_minutes, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :chain_position, presence: true, if: :chain_id?

  # Chain steps stay off the board until every earlier step is done.
  scope :unlocked, -> {
    where("tasks.chain_id IS NULL OR NOT EXISTS (SELECT 1 FROM tasks earlier WHERE earlier.chain_id = tasks.chain_id AND earlier.chain_position < tasks.chain_position AND earlier.archived_at IS NULL AND earlier.status <> 'done')")
  }

  # Adds a `logged_minutes_cache` column so lists can show logged time without an N+1.
  scope :with_logged_minutes, -> {
    select("tasks.*, COALESCE((SELECT SUM(EXTRACT(EPOCH FROM (COALESCE(te.ended_at, NOW()) - te.started_at)) / 60) FROM time_entries te WHERE te.task_id = tasks.id), 0)::int AS logged_minutes_cache")
  }

  before_validation :assign_number, on: :create
  before_save :stamp_completion, if: :status_changed?
  after_save_commit :notify_assignee, if: :saved_change_to_assignee_id?
  after_update_commit :notify_next_step_owner, if: -> { saved_change_to_status? && done? }

  MINUTES_PER_DAY = 8 * 60

  # Estimates are stored in minutes but entered in working days.
  def estimate_days
    estimate_minutes && estimate_minutes.to_f / MINUTES_PER_DAY
  end

  def estimate_days=(days)
    self.estimate_minutes = days.present? ? (days.to_f * MINUTES_PER_DAY).round : nil
  end

  # URLs use the project-scoped number (/projects/APO/tasks/97).
  def to_param
    number.to_s
  end

  # "APO-97"
  def key
    "#{project.key}-#{number}"
  end

  def logged_minutes
    return self[:logged_minutes_cache] if has_attribute?(:logged_minutes_cache)

    time_entries.sum("EXTRACT(EPOCH FROM (COALESCE(ended_at, NOW()) - started_at)) / 60").to_i
  end

  def over_estimate?
    estimate_minutes.present? && logged_minutes > estimate_minutes
  end

  def locked?
    chain.present? && chain.tasks.where("chain_position < ?", chain_position).where.not(status: "done").exists?
  end

  def chain_size
    chain&.tasks&.size
  end

  def archived? = archived_at.present?

  def archive! = update!(archived_at: Time.current)

  def restore! = update!(archived_at: nil)

  # Moves the card to another board column.
  def move_to!(new_status)
    update!(status: new_status)
  end

  # Statuses in board order, so "advance" means the next column to the right.
  def next_status
    STATUSES[STATUSES.index(status) + 1]
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

  def notify_assignee
    Notification.notify(user: assignee, kind: :task_assigned, subject: self) if assignee
  end

  # Finishing a step of a chain unlocks the next one for whoever owns it.
  def notify_next_step_owner
    following = next_in_chain
    Notification.notify(user: following.assignee, kind: :subtask_unlocked, subject: following) if following&.assignee
  end

  def stamp_completion
    self.completed_at = done? ? Time.current : nil
  end
end
