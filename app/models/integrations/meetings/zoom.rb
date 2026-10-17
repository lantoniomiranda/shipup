# Creates a scheduled Zoom meeting and returns its id and join link.
class Integrations::Meetings::Zoom < Integrations::Meetings::Base
  ENDPOINT = "https://api.zoom.us/v2/users/me/meetings".freeze

  private

  def create_remote
    body = post_json(ENDPOINT, {
      topic: meeting.topic.title, type: 2, start_time: meeting.starts_at.utc.iso8601,
      duration: meeting.duration_minutes, timezone: "UTC",
      settings: { auto_recording: meeting.transcribe? ? "cloud" : "none" }
    })
    Result.new(external_id: body.fetch("id").to_s, join_url: body.fetch("join_url"))
  end
end
