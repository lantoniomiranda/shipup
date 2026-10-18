class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  prepend_before_action :set_locale

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :use_user_time_zone
  before_action :follow_browser_time_zone

  private

  def set_locale
    I18n.locale = Locale.resolve(cookie: cookies[:locale], accept_language: request.env["HTTP_ACCEPT_LANGUAGE"])
  end

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

  def require_superadmin
    render_error(403) unless Current.user&.superadmin?
  end

  # Branded error page with the right status (use instead of `head :forbidden`).
  def render_error(code)
    render "errors/show", locals: { code: code }, status: code, layout: "application"
  end
end
