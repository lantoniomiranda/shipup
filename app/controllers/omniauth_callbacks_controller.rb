class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access

  def create
    user = User.from_omniauth(request.env.fetch("omniauth.auth"))
    start_new_session_for user
    redirect_to after_authentication_url
  rescue User::NotInvited
    redirect_to sign_in_path, alert: "ohship is invite-only. Ask your workspace admin to invite this email address."
  rescue KeyError, ArgumentError, ActiveRecord::RecordInvalid => error
    Rails.logger.warn("OAuth sign-in rejected: #{error.message}")
    redirect_to sign_in_path, alert: "We couldn't sign you in with that account."
  end

  def failure
    redirect_to sign_in_path, alert: "Sign-in was cancelled or failed. Please try again."
  end
end
