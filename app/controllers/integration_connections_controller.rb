# OAuth round-trip that links this deploy to Zoom, Google Meet or GitHub.
class IntegrationConnectionsController < ApplicationController
  before_action :require_superadmin
  before_action :set_provider

  def create
    return redirect_to integrations_path, alert: t("integrations.not_configured", provider: @provider.label) unless @provider.configured?

    session[:integration_state] = SecureRandom.hex(24)
    redirect_to oauth_client.authorize_url(state: session[:integration_state]), allow_other_host: true
  end

  def callback
    expected = session.delete(:integration_state)
    return redirect_to integrations_path, alert: t("integrations.expired") unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, params[:state].to_s)
    return redirect_to integrations_path, alert: t("integrations.denied", provider: @provider.label) if params[:code].blank?

    tokens = oauth_client.exchange(code: params[:code])
    save_connection(tokens)
    redirect_to integrations_path, notice: t("integrations.connected", provider: @provider.label)
  rescue Integrations::Error => error
    Rails.logger.warn("Integration connect failed: #{error.message}")
    redirect_to integrations_path, alert: t("integrations.could_not", provider: @provider.label)
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

  def save_connection(tokens)
    account = Integrations::AccountLookup.call(@provider.key, tokens.access_token)
    connection = IntegrationConnection.find_or_initialize_by(provider: @provider.key)
    connection.update!(connected_by: Current.user, external_account: account, access_token: tokens.access_token,
                       refresh_token: tokens.refresh_token || connection.refresh_token, expires_at: tokens.expires_at, scopes: tokens.scopes)
  end
end
