# Development only (routed in config/routes.rb): /dev/sign_in?email=ines@orbitlabs.dev&to=/integrations
class DevSessionsController < ApplicationController
  allow_unauthenticated_access

  def create
    return head :not_found unless Rails.env.development?

    user = User.find_by!(email: params.fetch(:email, "ines@orbitlabs.dev"))
    start_new_session_for user
    redirect_to params[:to].to_s.match?(%r{\A/[^/]}) ? params[:to].to_s : root_path
  end
end
