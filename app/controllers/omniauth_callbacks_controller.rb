class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access

  def create
    user = User.from_omniauth(request.env.fetch("omniauth.auth"))
    start_new_session_for user
    redirect_to after_authentication_url
  rescue User::NotInvited
    redirect_to sign_in_path, alert: t("sessions.invite_only")
  rescue KeyError, ArgumentError, ActiveRecord::RecordInvalid => error
    Rails.logger.warn("OAuth sign-in rejected: #{error.message}")
    redirect_to sign_in_path, alert: t("sessions.failed")
  end

  def failure
    redirect_to sign_in_path, alert: t("sessions.cancelled")
  end
end
