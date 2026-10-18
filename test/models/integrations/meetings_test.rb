require "test_helper"

class Integrations::MeetingsTest < ActiveSupport::TestCase
  JSON_HEADERS = { "Content-Type" => "application/json" }.freeze

  setup do
    @topic = topics(:refresh_tokens)
    @meeting = @topic.meetings.create!(organizer: users(:ines), provider: "zoom", starts_at: Time.utc(2026, 10, 22, 14), duration_minutes: 30)
    @meeting.participants.create!(user: users(:jonas), requirement: "optional")
  end

  def connect(provider, **attrs)
    IntegrationConnection.create!(provider: provider, external_account: "ops@orbitlabs.dev", connected_by: users(:ines),
                                  access_token: "tok", expires_at: 1.hour.from_now, **attrs)
  end

  test "provisions a Zoom meeting and posts the link in the topic chat" do
    connect("zoom")
    stub = stub_request(:post, "https://api.zoom.us/v2/users/me/meetings")
      .with(headers: { "Authorization" => "Bearer tok" },
            body: hash_including("topic" => @topic.title, "duration" => 30, "start_time" => "2026-10-22T14:00:00Z"))
      .to_return(status: 201, body: { id: 987, join_url: "https://zoom.us/j/987" }.to_json, headers: JSON_HEADERS)

    @meeting.provision!

    assert_requested stub
    assert_equal "987", @meeting.reload.external_id
    assert_equal "https://zoom.us/j/987", @meeting.join_url
    assert_includes @topic.messages.last.body, "https://zoom.us/j/987"
  end

  test "provisions a Google Meet link through a Calendar event" do
    connect("google_meet")
    @meeting.update!(provider: "google_meet")
    stub = stub_request(:post, %r{https://www.googleapis.com/calendar/v3/calendars/primary/events})
      .with(body: hash_including("summary" => @topic.title))
      .to_return(status: 200, body: { id: "evt1", hangoutLink: "https://meet.google.com/abc-defg-hij" }.to_json, headers: JSON_HEADERS)

    @meeting.provision!

    assert_requested stub
    assert_equal "https://meet.google.com/abc-defg-hij", @meeting.reload.join_url
  end

  test "fails clearly when the provider is not connected the provider" do
    assert_raises(Integrations::NotConnected) { @meeting.provision! }
  end

  test "surfaces provider errors without saving a link" do
    connect("zoom")
    stub_request(:post, "https://api.zoom.us/v2/users/me/meetings").to_return(status: 401, body: "{}", headers: JSON_HEADERS)

    assert_raises(Integrations::Error) { @meeting.provision! }
    assert_nil @meeting.reload.join_url
  end

  test "refreshes an expired token before calling the provider" do
    ENV["ZOOM_CLIENT_ID"] = "id"
    ENV["ZOOM_CLIENT_SECRET"] = "secret"
    connect("zoom", expires_at: 1.minute.ago, refresh_token: "rt")
    stub_request(:post, "https://zoom.us/oauth/token")
      .to_return(status: 200, body: { access_token: "fresh", refresh_token: "rt2", expires_in: 3600 }.to_json, headers: JSON_HEADERS)
    stub = stub_request(:post, "https://api.zoom.us/v2/users/me/meetings")
      .with(headers: { "Authorization" => "Bearer fresh" })
      .to_return(status: 201, body: { id: 1, join_url: "https://zoom.us/j/1" }.to_json, headers: JSON_HEADERS)

    @meeting.provision!

    assert_requested stub
  ensure
    ENV.delete("ZOOM_CLIENT_ID")
    ENV.delete("ZOOM_CLIENT_SECRET")
  end
end
