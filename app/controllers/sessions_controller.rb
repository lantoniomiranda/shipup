class SessionsController < ApplicationController
  allow_unauthenticated_access only: :new
  skip_before_action :require_workspace_access, only: :destroy

  def new
    redirect_to root_path if authenticated?
  end

  def destroy
    terminate_session
    redirect_to sign_in_path, status: :see_other
  end
end
