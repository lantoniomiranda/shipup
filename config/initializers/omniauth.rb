# Google and Microsoft are the only ways to sign in. Credentials come from the
# environment (see .env.example); request-phase GETs are disabled for CSRF safety.
OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.logger = Rails.logger

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"],
    scope: "email,profile", prompt: "select_account"

  provider :entra_id,
    client_id: ENV["MICROSOFT_CLIENT_ID"],
    client_secret: ENV["MICROSOFT_CLIENT_SECRET"],
    tenant_id: ENV.fetch("MICROSOFT_TENANT_ID", "common")
end
