class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_workspace

  private

  def require_workspace_admin
    render_error(403) unless Current.user&.role_in(Current.workspace) == "admin"
  end

  # Branded error page with the right status (use instead of `head :forbidden`).
  def render_error(code)
    render "errors/show", locals: { code: code }, status: code, layout: "application"
  end

  def set_current_workspace
    Current.workspace ||= Current.user&.workspaces&.first
  end
end
