Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # OAuth is the only way in. OmniAuth owns POST /auth/:provider (request phase).
  get "sign_in", to: "sessions#new"
  delete "sign_out", to: "sessions#destroy"
  match "auth/:provider/callback", to: "omniauth_callbacks#create", via: %i[get post], as: :omniauth_callback
  get "auth/failure", to: "omniauth_callbacks#failure"

  root "projects#index"
end
