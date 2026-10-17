# Receives GitHub webhooks. Authenticity is proven by the HMAC signature, not a session.
class Webhooks::GithubController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  before_action :verify_signature

  def create
    payload = JSON.parse(request.raw_post)
    Integrations::Github::PullRequestSync.call(payload) if request.headers["X-GitHub-Event"] == "pull_request"
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def verify_signature
    secret = ENV["GITHUB_WEBHOOK_SECRET"].to_s
    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, request.raw_post)}"
    given = request.headers["X-Hub-Signature-256"].to_s

    head :unauthorized unless secret.present? && ActiveSupport::SecurityUtils.secure_compare(expected, given)
  end
end
