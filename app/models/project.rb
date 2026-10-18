class Project < ApplicationRecord
  include Hued

  ICONS = %w[rocket smartphone workflow receipt palette].freeze
  STATUSES = %w[active completed].freeze

  has_many :project_memberships, dependent: :destroy
  has_many :invitations, dependent: :destroy
  has_many :members, through: :project_memberships, source: :user
  has_many :sprints, dependent: :destroy
  has_many :topics, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :chains, dependent: :destroy
  has_many :labels, dependent: :destroy
  has_many :project_clients, dependent: :destroy
  has_many :clients, through: :project_clients
  has_many :github_repositories, dependent: :destroy

  enum :status, STATUSES.index_with(&:itself), default: "active", validate: true

  normalizes :key, with: ->(key) { key.strip.upcase }

  validates :name, presence: true
  validates :key, presence: true, format: { with: /\A[A-Z]{2,5}\z/ }, uniqueness: true
  validates :icon, inclusion: { in: ICONS }

  scope :ordered, -> { order(:position, :name) }

  # Admins see every project, everyone else the ones they were invited to.
  scope :visible_to, ->(user) { user.superadmin? ? all : where(id: user.project_memberships.select(:project_id)) }

  # Share of the 20 XP-bar segments that are lit for a 0-100 progress value.
  XP_SEGMENTS = 20

  def self.xp_segments_lit(percent)
    (percent * XP_SEGMENTS / 100.0).ceil
  end

  # URLs use the key (APO), not the numeric id.
  def to_param
    key
  end

  # Superadmins and this project's admins may plan sprints, invite people and archive things.
  def managed_by?(user)
    user.superadmin? || project_memberships.admin.exists?(user_id: user.id)
  end

  # The one sprint being worked on; it is what the board shows.
  def active_sprint
    sprints.active.first
  end

  # Hands out the next task number (APO-1, APO-2…). The row lock keeps concurrent
  # creators from receiving the same number.
  def next_task_number!
    with_lock do
      increment!(:last_task_number)
      last_task_number
    end
  end
end
