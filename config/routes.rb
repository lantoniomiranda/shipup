Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # OAuth is the only way in. OmniAuth owns POST /auth/:provider (request phase).
  get "sign_in", to: "sessions#new"
  delete "sign_out", to: "sessions#destroy"
  patch "locale", to: "locales#update"
  match "auth/:provider/callback", to: "omniauth_callbacks#create", via: %i[get post], as: :omniauth_callback
  get "auth/failure", to: "omniauth_callbacks#failure"

  # Integrations (admins only): connect Zoom / Google Meet / GitHub and pick the meeting tool.
  get "integrations", to: "integrations#index"
  scope "integrations/:provider", constraints: { provider: /zoom|google_meet|github/ } do
    post "connection", to: "integration_connections#create", as: :connect_integration
    get "callback", to: "integration_connections#callback", as: :integration_callback
  end
  patch "meeting_tool", to: "meeting_tools#update"
  resources :time_off_requests, path: "time_off", only: %i[index new create update]
  resource :search, only: :show
  resource :account, only: %i[show update]
  resource :appearance, only: %i[show update]
  resources :github_repositories, only: %i[index create destroy], path: "integrations/github/repositories"

  post "webhooks/github", to: "webhooks/github#create"

  # Projects are addressed by their key (/projects/APO/topics).
  resources :projects, only: %i[show new create update] do
    resource :board, only: :show
    resource :backlog, only: :show
    resources :sprints, only: %i[new create] do
      member do
        patch :start
        patch :complete
      end
    end
    resource :timeline, only: :show
    resource :analytics, only: :show
    resources :clients, only: %i[index new create destroy], controller: "project_clients" do
      patch :restore, on: :member
    end
    resources :members, only: %i[index update destroy], controller: "project_members"
    resources :invitations, only: %i[create destroy] do
      post :resend, on: :member
    end
    resources :tasks, only: %i[show update] do
      post :advance, on: :member
      patch :schedule, on: :member
      patch :archive, on: :member
      patch :restore, on: :member
      resources :messages, only: %i[create update destroy], controller: "task_messages"
      resource :timer, only: %i[create destroy], controller: "task_timers"
    end
    resources :topics, only: %i[index show new create] do
      get :similar, on: :collection
      patch :cancel, on: :member
      patch :reopen, on: :member
      resource :vote, only: :create, controller: "topic_votes"
      resources :messages, only: %i[create update destroy], controller: "topic_messages"
      resources :tasks, only: %i[new create], controller: "topic_tasks"
      resources :chains, only: %i[new create], controller: "topic_chains"
      resources :meetings, only: %i[new create], controller: "topic_meetings"
    end
  end

  # Development shortcut: OAuth needs real client credentials, so skip it locally.
  get "dev/sign_in", to: "dev_sessions#create" if Rails.env.development?

  # Error pages. Rails calls these paths itself (config.exceptions_app); they also work as plain URLs.
  match "/:code", to: "errors#show", via: :all, constraints: { code: /400|403|404|406|422|500/ }

  root "projects#index"
end
