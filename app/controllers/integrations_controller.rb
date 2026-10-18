# Connectors: connect Zoom, Google Meet and GitHub, and see the AI status. Admin only.
class IntegrationsController < ApplicationController
  layout "app"
  before_action :require_workspace_admin

  def index
    @workspace = Current.workspace
    @connections = @workspace.integration_connections.index_by(&:provider)
  end
end
