# Shared behaviour of a chat message in a thread (a topic or a task): it can quote an earlier
# message of the same thread, be edited by its author, and be removed. Removal is soft so the
# replies that quote it keep their context ("Message removed").
#
#   class TaskMessage < ApplicationRecord
#     include ChatMessage
#     chat_message thread: :task
#   end
module ChatMessage
  extend ActiveSupport::Concern

  included do
    belongs_to :author, class_name: "User"
    belongs_to :parent, class_name: name, optional: true
    has_many :replies, class_name: name, foreign_key: :parent_id, inverse_of: :parent, dependent: :nullify

    validates :body, presence: true, unless: :deleted?
    validate :parent_in_same_thread
  end

  class_methods do
    # Declares which association is the thread (:topic or :task) so replies can't cross threads.
    def chat_message(thread:)
      @thread_association = thread
    end

    attr_reader :thread_association
  end

  def thread = public_send(self.class.thread_association)

  def deleted? = deleted_at.present?
  def edited? = edited_at.present? && !deleted?

  def editable_by?(user) = !deleted? && author_id == user.id

  # Authors can remove their own messages; workspace admins and project managers can moderate.
  def removable_by?(user, project)
    !deleted? && (author_id == user.id || project.managed_by?(user))
  end

  def edit!(new_body)
    update!(body: new_body, edited_at: Time.current)
  end

  def remove!
    update!(body: "", deleted_at: Time.current)
  end

  # A short single-line quote for the "replying to…" block.
  def excerpt(length = 90)
    deleted? ? "Message removed" : body.to_s.squish.truncate(length)
  end

  private

  def parent_in_same_thread
    return unless parent

    errors.add(:parent, "must be in the same conversation") unless parent.thread == thread
  end
end
