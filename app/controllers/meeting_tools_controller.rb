# Saves which connected tool the whole workspace uses for meeting links.
class MeetingToolsController < ApplicationController
  before_action :require_workspace_admin

  def update
    provider = params[:provider].to_s

    if Current.workspace.connection_for(provider) && Current.workspace.update(meeting_provider: provider)
      redirect_to root_path, notice: "#{Integrations.provider(provider).label} is now your meeting tool."
    else
      redirect_to integrations_path, alert: "Connect a meeting tool first, then continue."
    end
  end
end
