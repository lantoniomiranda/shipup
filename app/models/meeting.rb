class Meeting < ApplicationRecord
  belongs_to :topic
  belongs_to :organizer, class_name: "User"
  has_many :participants, class_name: "MeetingParticipant", dependent: :destroy
  has_many :users, through: :participants
  has_one :digest, class_name: "MeetingDigest", dependent: :destroy

  validates :provider, inclusion: { in: Workspace::MEETING_PROVIDERS }
  validates :starts_at, presence: true
  validates :duration_minutes, numericality: { greater_than: 0, less_than_or_equal_to: 480 }

  # Creates the call with the workspace's meeting tool and posts the link in the topic chat.
  def provision!
    workspace = topic.project.workspace
    connection = workspace.connection_for(provider) or raise Integrations::NotConnected, "#{provider} is not connected"

    Integrations::Meetings::Base.for(provider).new(self, connection).call
    topic.messages.create!(author: organizer, body: "Live discussion #{starts_at.utc.strftime('%a %-d %b, %H:%M UTC')}: #{join_url}")
    self
  end

  def ends_at
    starts_at + duration_minutes.minutes
  end
end
