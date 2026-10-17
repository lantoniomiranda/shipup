# Google Meet links come from a Calendar event with a conference request attached.
class Integrations::Meetings::GoogleMeet < Integrations::Meetings::Base
  ENDPOINT = "https://www.googleapis.com/calendar/v3/calendars/primary/events?conferenceDataVersion=1&sendUpdates=all".freeze

  private

  def create_remote
    body = post_json(ENDPOINT, {
      summary: meeting.topic.title,
      start: { dateTime: meeting.starts_at.utc.iso8601 }, end: { dateTime: meeting.ends_at.utc.iso8601 },
      attendees: meeting.users.map { |user| { email: user.email, optional: meeting.participants.find_by(user: user).optional? } },
      conferenceData: { createRequest: { requestId: SecureRandom.uuid, conferenceSolutionKey: { type: "hangoutsMeet" } } }
    })
    Result.new(external_id: body.fetch("id"), join_url: body.fetch("hangoutLink"))
  end
end
