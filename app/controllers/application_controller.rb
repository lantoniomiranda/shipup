class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_workspace
  before_action :require_workspace_access

  private

  def require_workspace_admin
    render_error(403) unless Current.user&.role_in(Current.workspace) == "admin"
  end

  # Branded error page with the right status (use instead of `head :forbidden`).
  def render_error(code)
    render "errors/show", locals: { code: code }, status: code, layout: "application"
  end

  # The tenant for this request: the one picked in the switcher, else the first active one.
  def set_current_workspace
    return unless Current.user

    workspaces = Current.user.workspaces
    Current.workspace ||= workspaces.find_by(id: session[:workspace_id]) || workspaces.active.order(:id).first || workspaces.order(:id).first
  end

  # Signed-in people need a usable workspace: staff without one go to the backoffice, suspended
  # tenants see why, and people who belong to nothing are told so.
  def require_workspace_access
    return unless Current.user

    if Current.workspace.nil?
      Current.user.platform_admin? ? redirect_to(backoffice_root_path) : render("workspaces/none", status: :forbidden, layout: "application")
    elsif Current.workspace.suspended?
      render "workspaces/suspended", status: :forbidden, layout: "application"
    end
  end
end
