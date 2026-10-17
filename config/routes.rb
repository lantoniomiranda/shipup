Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # OAuth is the only way in. OmniAuth owns POST /auth/:provider (request phase).
  get "sign_in", to: "sessions#new"
  delete "sign_out", to: "sessions#destroy"
  match "auth/:provider/callback", to: "omniauth_callbacks#create", via: %i[get post], as: :omniauth_callback
  get "auth/failure", to: "omniauth_callbacks#failure"

  # Workspace integrations (admin only): connect Zoom / Google Meet / GitHub and pick the meeting tool.
  get "integrations", to: "integrations#index"
  scope "integrations/:provider", constraints: { provider: /zoom|google_meet|github/ } do
    post "connection", to: "integration_connections#create", as: :connect_integration
    get "callback", to: "integration_connections#callback", as: :integration_callback
  end
  patch "meeting_tool", to: "meeting_tools#update"

  post "webhooks/github", to: "webhooks/github#create"

  # Development shortcut: OAuth needs real client credentials, so skip it locally.
  get "dev/sign_in", to: "dev_sessions#create" if Rails.env.development?

  root "projects#index"
end
