class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  prepend_before_action :set_locale

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def set_locale
    I18n.locale = Locale.resolve(cookie: cookies[:locale], accept_language: request.env["HTTP_ACCEPT_LANGUAGE"])
  end

  def require_superadmin
    render_error(403) unless Current.user&.superadmin?
  end

  # Branded error page with the right status (use instead of `head :forbidden`).
  def render_error(code)
    render "errors/show", locals: { code: code }, status: code, layout: "application"
  end
end
