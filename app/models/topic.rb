# A conversation about an issue or a feature request, which can turn into work.
class Topic < ApplicationRecord
  KINDS = %w[issue feature].freeze
  STATUSES = %w[open canceled approved].freeze

  belongs_to :project
  belongs_to :author, class_name: "User"
  belongs_to :client, optional: true
  has_many :votes, class_name: "TopicVote", dependent: :destroy
  has_many :messages, class_name: "TopicMessage", dependent: :destroy
  has_many :meetings, dependent: :destroy
  has_many :tasks, dependent: :nullify
  has_many :chains, dependent: :nullify

  enum :kind, KINDS.index_with(&:itself), default: "feature", validate: true
  enum :status, STATUSES.index_with(&:itself), default: "open", validate: true

  validates :title, presence: true

  scope :top, -> { order(votes_score: :desc, created_at: :desc) }
  scope :recent, -> { order(created_at: :desc) }

  def vote_by(user)
    votes.find_by(user: user)
  end

  # Casts, flips or (when repeated) retracts a vote and refreshes the cached score.
  def cast_vote(user, value)
    vote = votes.find_or_initialize_by(user: user)
    vote.persisted? && vote.value == value ? vote.destroy! : vote.update!(value: value)
    refresh_votes_score!
  end

  def refresh_votes_score!
    update!(votes_score: votes.sum(:value))
  end
end
