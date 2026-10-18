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
  resources :time_off_requests, path: "time_off", only: %i[index new create update]
  post "workspaces/:id/switch", to: "workspace_switches#create", as: :switch_workspace
  resources :memberships, path: "people", only: %i[index update destroy]
  resources :invitations, only: %i[create destroy] do
    post :resend, on: :member
  end
  resources :notifications, only: %i[index show] do
    post :read_all, on: :collection
  end
  get "settings/keyboard", to: "keyboard_settings#show", as: :keyboard_settings
  patch "settings/keyboard", to: "keyboard_settings#update"
  delete "settings/keyboard", to: "keyboard_settings#destroy"
  resource :search, only: :show
  resource :account, only: %i[show update]
  resource :appearance, only: %i[show update]
  resources :github_repositories, only: %i[index create destroy], path: "integrations/github/repositories"

  post "webhooks/github", to: "webhooks/github#create"

  # Projects are addressed by their key (/projects/APO/topics).
  resources :projects, only: %i[show new create] do
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
    resources :clients, only: %i[index new create], controller: "project_clients"
    resources :tasks, only: %i[show update] do
      post :advance, on: :member
      patch :schedule, on: :member
      resources :messages, only: %i[create update destroy], controller: "task_messages"
      resource :timer, only: %i[create destroy], controller: "task_timers"
    end
    resources :topics, only: %i[index show new create] do
      get :similar, on: :collection
      resource :vote, only: :create, controller: "topic_votes"
      resources :messages, only: %i[create update destroy], controller: "topic_messages"
      resources :tasks, only: %i[new create], controller: "topic_tasks"
      resources :chains, only: %i[new create], controller: "topic_chains"
      resources :meetings, only: %i[new create], controller: "topic_meetings"
    end
  end

  # ohship staff only: manage customers (tenants).
  namespace :backoffice do
    root "dashboards#show"
    resources :tenants, controller: "workspaces", only: %i[index show new create edit update] do
      member do
        patch :suspend
        patch :reactivate
      end
      resources :invitations, only: %i[create destroy] do
        post :resend, on: :member
      end
    end
  end

  # Development shortcut: OAuth needs real client credentials, so skip it locally.
  get "dev/sign_in", to: "dev_sessions#create" if Rails.env.development?

  # Error pages. Rails calls these paths itself (config.exceptions_app); they also work as plain URLs.
  match "/:code", to: "errors#show", via: :all, constraints: { code: /400|403|404|406|422|500/ }

  # "/" is the public landing page for visitors and the dashboard for signed-in people.
  get "/", to: "landing#show", constraints: VisitorConstraint, as: :landing
  root "projects#index"
end
