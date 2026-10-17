# The workspace switcher in the top bar: remembers which tenant this browser session is working in.
class WorkspaceSwitchesController < ApplicationController
  skip_before_action :require_workspace_access

  def create
    workspace = Current.user.workspaces.find_by(id: params[:id])
    return render_error(404) unless workspace

    session[:workspace_id] = workspace.id
    redirect_to root_path, status: :see_other
  end
end
