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

  after_create_commit :notify_members

  scope :top, -> { order(votes_score: :desc, created_at: :desc) }
  scope :recent, -> { order(created_at: :desc) }

  # Open topics the user took part in where someone else spoke last.
  scope :awaiting_reply_from, ->(user) {
    open.where(<<~SQL.squish, user_id: user.id)
      (topics.author_id = :user_id OR EXISTS (SELECT 1 FROM topic_messages m WHERE m.topic_id = topics.id AND m.author_id = :user_id))
      AND COALESCE((SELECT m.author_id FROM topic_messages m WHERE m.topic_id = topics.id ORDER BY m.created_at DESC, m.id DESC LIMIT 1), topics.author_id) <> :user_id
    SQL
  }

  # Adds a 0-1 `title_score` column: how closely each title matches `text` (whole-title trigram
  # similarity blended with how much each side covers the other, the weaker direction wins). See
  # TopicSimilarity, which combines it with the discussion text.
  scope :with_title_score, ->(text) {
    score = sanitize_sql_array([ "(0.5 * similarity(topics.title, ?) + 0.5 * LEAST(word_similarity(?, topics.title), word_similarity(topics.title, ?)))", text, text, text ])
    select("topics.*, #{score} AS title_score")
  }

  # A task or chain was created from this topic: it is no longer just open.
  def approve!
    approved! if open?
  end

  # The topic is dropped (not planned, duplicate, out of scope). It stays readable and can be reopened.
  def cancel!
    canceled!
  end

  # Back to the discussion; topics that already produced work go back to approved.
  def reopen!
    update!(status: tasks.exists? || chains.exists? ? "approved" : "open")
  end

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

  private

  def notify_members
    project.members.where.not(id: author_id).find_each { |member| Notification.notify(user: member, kind: :new_topic, subject: self, actor: author) }
  end
end
