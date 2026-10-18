ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: [ Etc.nprocessors, 4 ].min)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # A developer's .env (real LLM key and model) must never leak into tests: start every test with AI off.
    LLM_ENV = %w[LLM_ENABLED LLM_API_KEY LLM_MODEL LLM_BASE_URL].freeze

    setup do
      @llm_env_before = ENV.to_h.slice(*LLM_ENV)
      LLM_ENV.each { |key| ENV.delete(key) }
    end

    teardown do
      LLM_ENV.each { |key| @llm_env_before.key?(key) ? ENV[key] = @llm_env_before[key] : ENV.delete(key) }
    end
  end
end

# Auth helpers for integration tests. OAuth is the only real sign-in path, so
# tests sign in by stubbing OmniAuth's mock hash for the given user.
module SignInHelper
  def sign_in_as(user, provider: "google_oauth2")
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[provider.to_sym] = omniauth_hash(provider, uid: "uid-#{user.id}", email: user.email, name: user.name)
    post "/auth/#{provider}"
    follow_redirect!
  end

  def omniauth_hash(provider, uid:, email:, name:)
    OmniAuth::AuthHash.new(provider: provider, uid: uid, info: { email: email, name: name })
  end

  def sign_out
    delete sign_out_path
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.clear
  end
end

# Provides fake client credentials so OAuth providers count as "configured" in tests.
module IntegrationCredentials
  ENV_KEYS = %w[ZOOM_CLIENT_ID ZOOM_CLIENT_SECRET GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GITHUB_CLIENT_ID GITHUB_CLIENT_SECRET].freeze

  def with_integration_credentials
    original = ENV.to_h.slice(*ENV_KEYS)
    ENV_KEYS.each { |key| ENV[key] = "test-#{key.downcase}" }
    yield
  ensure
    ENV_KEYS.each { |key| original.key?(key) ? ENV[key] = original[key] : ENV.delete(key) }
  end
end

# Switches a provider on for the block: with_llm("gemini") { ... }
module LlmHelper
  ENV_KEYS = %w[LLM_ENABLED LLM_API_KEY LLM_MODEL LLM_BASE_URL].freeze

  def with_llm(provider, api_key: "test-key", **extra)
    original = ENV.to_h.slice(*ENV_KEYS)
    ENV["LLM_ENABLED"] = provider
    ENV["LLM_API_KEY"] = api_key
    extra.each { |name, value| ENV["LLM_#{name.to_s.upcase}"] = value }
    yield
  ensure
    ENV_KEYS.each { |key| original.key?(key) ? ENV[key] = original[key] : ENV.delete(key) }
  end
end
