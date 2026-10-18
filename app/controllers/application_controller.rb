class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_current_workspace
  before_action :follow_browser_time_zone
  around_action :use_user_time_zone
  before_action :require_workspace_access

  private

  # The browser reports its zone in a cookie (timezone_controller.js). Until the person picks one
  # in their account, adopt it, so clocks and meeting times are theirs without any setup.
  def follow_browser_time_zone
    user = Current.user
    zone = cookies[:browser_time_zone].to_s
    return unless user && user.time_zone_auto? && zone != user.time_zone && TZInfo::Timezone.all_identifiers.include?(zone)

    user.update_columns(time_zone: zone)
  end

  # Dates and times render in the signed-in person's zone (storage stays UTC).
  def use_user_time_zone(&block)
    Time.use_zone(Current.user&.time_zone || Time.zone, &block)
  end

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

  # Signed-in people need a usable workspace: suspended tenants see why, and people who belong to
  # nothing are told so.
  def require_workspace_access
    return unless Current.user

    if Current.workspace.nil?
      render "workspaces/none", status: :forbidden, layout: "application"
    elsif Current.workspace.suspended?
      render "workspaces/suspended", status: :forbidden, layout: "application"
    end
  end
end
