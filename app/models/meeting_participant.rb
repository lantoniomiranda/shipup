class MeetingParticipant < ApplicationRecord
  REQUIREMENTS = %w[required optional].freeze

  belongs_to :meeting
  belongs_to :user

  enum :requirement, REQUIREMENTS.index_with(&:itself), default: "required", validate: true

  validates :user_id, uniqueness: { scope: :meeting_id }

  after_create_commit { Notification.notify(user: user, kind: :meeting_invite, subject: meeting, actor: meeting.organizer) }
end
