# Remembers the language on this browser. Works signed out, so the sign-in screen can change too.
class LocalesController < ApplicationController
  allow_unauthenticated_access

  def update
    locale = Locale.pick(params[:locale])
    cookies.permanent[:locale] = { value: locale, httponly: true, same_site: :lax } if locale
    redirect_back fallback_location: (authenticated? ? root_path : sign_in_path), status: :see_other
  end
end
