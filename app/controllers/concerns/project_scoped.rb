# Controllers nested under /projects/:project_id. Projects are looked up inside the
# current workspace only, so another workspace's project is simply a 404.
module ProjectScoped
  extend ActiveSupport::Concern

  included do
    layout "app"
    before_action :set_project
    helper_method :current_project
  end

  private

  def set_project
    @project = Current.workspace.projects.find_by!(key: params[:project_id].to_s.upcase)
  end

  def current_project
    @project
  end
end
