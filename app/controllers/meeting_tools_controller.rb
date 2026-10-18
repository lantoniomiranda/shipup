# Saves which connected tool everyone uses for meeting links.
class MeetingToolsController < ApplicationController
  before_action :require_superadmin

  def update
    provider = params[:provider].to_s

    if IntegrationConnection.for(provider) && Setting.current.update(meeting_provider: provider)
      redirect_to integrations_path, notice: t("integrations.now_tool", provider: Integrations.provider(provider).label)
    else
      redirect_to integrations_path, alert: t("integrations.connect_first")
    end
  end
end
