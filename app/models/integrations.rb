# Third-party providers this deploy can connect. Each is an OAuth2 authorization-code app
# configured from the environment (see .env.example).
module Integrations
  Provider = Data.define(:key, :label, :authorize_url, :token_url, :scopes, :client_id_env, :client_secret_env, :extra_authorize_params, :client_auth) do
    def client_id = ENV[client_id_env]
    def client_secret = ENV[client_secret_env]
    def configured? = client_id.present? && client_secret.present?
    def meeting_tool? = Setting::MEETING_PROVIDERS.include?(key)
  end

  PROVIDERS = {
    "zoom" => Provider.new(
      key: "zoom", label: "Zoom",
      authorize_url: "https://zoom.us/oauth/authorize", token_url: "https://zoom.us/oauth/token",
      scopes: %w[meeting:write user:read], client_id_env: "ZOOM_CLIENT_ID", client_secret_env: "ZOOM_CLIENT_SECRET",
      extra_authorize_params: {}, client_auth: :basic
    ),
    "google_meet" => Provider.new(
      key: "google_meet", label: "Google Meet",
      authorize_url: "https://accounts.google.com/o/oauth2/v2/auth", token_url: "https://oauth2.googleapis.com/token",
      scopes: %w[https://www.googleapis.com/auth/calendar.events email], client_id_env: "GOOGLE_CLIENT_ID", client_secret_env: "GOOGLE_CLIENT_SECRET",
      extra_authorize_params: { access_type: "offline", prompt: "consent" }, client_auth: :body
    ),
    "github" => Provider.new(
      key: "github", label: "GitHub",
      authorize_url: "https://github.com/login/oauth/authorize", token_url: "https://github.com/login/oauth/access_token",
      scopes: %w[repo read:user], client_id_env: "GITHUB_CLIENT_ID", client_secret_env: "GITHUB_CLIENT_SECRET",
      extra_authorize_params: {}, client_auth: :body
    )
  }.freeze

  def self.provider(key)
    PROVIDERS.fetch(key.to_s) { raise ArgumentError, "Unknown integration: #{key}" }
  end

  class Error < StandardError; end
  class NotConnected < Error; end
end
