# "Set up your workspace" — choose and connect the meeting tool. Admin only.
class IntegrationsController < ApplicationController
  before_action :require_workspace_admin

  def index
    @workspace = Current.workspace
    @connections = @workspace.integration_connections.index_by(&:provider)
  end
end
