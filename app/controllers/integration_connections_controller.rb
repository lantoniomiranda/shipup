# OAuth round-trip that links a workspace to Zoom, Google Meet or GitHub.
class IntegrationConnectionsController < ApplicationController
  before_action :require_workspace_admin
  before_action :set_provider

  def create
    return redirect_to integrations_path, alert: "#{@provider.label} isn't configured on this server." unless @provider.configured?

    session[:integration_state] = SecureRandom.hex(24)
    redirect_to oauth_client.authorize_url(state: session[:integration_state]), allow_other_host: true
  end

  def callback
    expected = session.delete(:integration_state)
    return redirect_to integrations_path, alert: "That connection attempt expired. Please try again." unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, params[:state].to_s)
    return redirect_to integrations_path, alert: "#{@provider.label} access was not granted." if params[:code].blank?

    tokens = oauth_client.exchange(code: params[:code])
    connect_workspace(tokens)
    redirect_to integrations_path, notice: "#{@provider.label} connected."
  rescue Integrations::Error => error
    Rails.logger.warn("Integration connect failed: #{error.message}")
    redirect_to integrations_path, alert: "We couldn't connect #{@provider.label}. Please try again."
  end

  private

  def set_provider
    @provider = Integrations.provider(params[:provider])
  rescue ArgumentError
    head :not_found
  end

  def oauth_client
    Integrations::OauthClient.new(@provider, redirect_uri: integration_callback_url(provider: @provider.key))
  end

  def connect_workspace(tokens)
    account = Integrations::AccountLookup.call(@provider.key, tokens.access_token)
    connection = Current.workspace.integration_connections.find_or_initialize_by(provider: @provider.key)
    connection.update!(connected_by: Current.user, external_account: account, access_token: tokens.access_token,
                       refresh_token: tokens.refresh_token || connection.refresh_token, expires_at: tokens.expires_at, scopes: tokens.scopes)
  end
end
