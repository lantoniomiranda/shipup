# Controllers nested under /projects/:project_id. Projects are looked up among the ones the
# signed-in user can see, so a project they were not invited to is simply a 404.
module ProjectScoped
  extend ActiveSupport::Concern

  included do
    layout "app"
    before_action :set_project
    helper_method :current_project
  end

  private

  def set_project
    @project = Project.visible_to(Current.user).find_by!(key: params[:project_id].to_s.upcase)
  end

  # For actions only admins and the project's admins may take.
  def require_project_admin
    render_error(403) unless @project.managed_by?(Current.user)
  end

  def current_project
    @project
  end
end
