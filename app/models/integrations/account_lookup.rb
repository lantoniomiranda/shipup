# Asks the provider who just connected, so the setup screen can say "Connected as ops@orbitlabs.dev".
class Integrations::AccountLookup
  ENDPOINTS = {
    "zoom" => [ "https://api.zoom.us/v2/users/me", "email" ],
    "google_meet" => [ "https://www.googleapis.com/oauth2/v3/userinfo", "email" ],
    "github" => [ "https://api.github.com/user", "login" ]
  }.freeze

  def self.call(provider_key, access_token)
    url, field = ENDPOINTS.fetch(provider_key)
    response = Faraday.new { |f| f.response :json, content_type: /json/ }.get(url) do |request|
      request.headers["Authorization"] = "Bearer #{access_token}"
      request.headers["Accept"] = "application/json"
    end
    response.body.fetch(field) { raise Integrations::Error, "Could not read the #{provider_key} account" }
  end
end
