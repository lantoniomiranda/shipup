class Meeting < ApplicationRecord
  belongs_to :topic
  belongs_to :organizer, class_name: "User"
  has_many :participants, class_name: "MeetingParticipant", dependent: :destroy
  has_many :users, through: :participants
  has_one :digest, class_name: "MeetingDigest", dependent: :destroy

  validates :provider, inclusion: { in: Workspace::MEETING_PROVIDERS }
  validates :starts_at, presence: true
  validates :duration_minutes, numericality: { greater_than: 0, less_than_or_equal_to: 480 }

  def ends_at
    starts_at + duration_minutes.minutes
  end
end
