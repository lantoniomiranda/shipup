# The public front door ("/" for visitors). Signed-in people never reach it: the router sends
# them to the dashboard (see VisitorConstraint in config/routes.rb).
class LandingController < ApplicationController
  allow_unauthenticated_access
  layout "application"

  def show
  end
end
