# Everything under /backoffice is for ShipUp staff (users.platform_admin). Anyone else gets a 404
# so the area's existence isn't advertised.
class Backoffice::BaseController < ApplicationController
  layout "backoffice"
  before_action :require_platform_admin

  private

  def require_platform_admin
    render_error(404) unless Current.user&.platform_admin?
  end
end
