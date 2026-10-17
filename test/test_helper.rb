ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all
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
