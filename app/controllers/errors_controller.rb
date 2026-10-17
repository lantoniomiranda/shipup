# Branded error pages. Rails routes failed requests here (config.exceptions_app), so this
# must work without a session and never raise.
class ErrorsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :set_current_workspace, raise: false
  skip_forgery_protection
  before_action :resume_session_quietly

  def show
    code = params[:code].to_i
    render "errors/show", locals: { code: code }, status: code, layout: "application"
  end

  private

  # Show the signed-in variant when a session cookie exists, but never fail because of one.
  def resume_session_quietly
    resume_session
  rescue StandardError
    nil
  end
end
