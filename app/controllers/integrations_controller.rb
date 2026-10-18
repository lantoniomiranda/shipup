# Connectors: connect Zoom, Google Meet and GitHub, and see the AI status. Superadmins only.
class IntegrationsController < ApplicationController
  layout "settings"
  before_action :require_superadmin

  def index
    @default_tool = Setting.meeting_provider
    @connections = IntegrationConnection.all.index_by(&:provider)
  end
end
