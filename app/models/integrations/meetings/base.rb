# Template for "create a video call with provider X for this meeting".
# Subclasses implement #create_remote and return a Result.
class Integrations::Meetings::Base
  Result = Data.define(:external_id, :join_url)

  def self.for(provider)
    { "zoom" => Integrations::Meetings::Zoom, "google_meet" => Integrations::Meetings::GoogleMeet }.fetch(provider)
  end

  def initialize(meeting, connection)
    @meeting = meeting
    @connection = connection
  end

  # Creates the call remotely and stores its id/link on the meeting.
  def call
    result = create_remote
    meeting.update!(external_id: result.external_id, join_url: result.join_url)
    meeting
  end

  private

  attr_reader :meeting, :connection

  def post_json(url, payload)
    response = Faraday.new { |f| f.response :json, content_type: /json/ }.post(url) do |request|
      request.headers["Authorization"] = "Bearer #{connection.fresh_access_token!}"
      request.headers["Content-Type"] = "application/json"
      request.body = payload.to_json
    end
    raise Integrations::Error, "#{connection.provider_config.label} rejected the meeting (#{response.status})" unless response.success?

    response.body
  end
end
