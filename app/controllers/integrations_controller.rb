# "Set up ShipUp" — choose and connect the meeting tool. Admin only.
class IntegrationsController < ApplicationController
  before_action :require_superadmin

  def index
    @selected_tool = Setting.meeting_provider
    @connections = IntegrationConnection.all.index_by(&:provider)
  end
end
