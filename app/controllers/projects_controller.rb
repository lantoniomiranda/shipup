class ProjectsController < ApplicationController
  layout "app"
  before_action :require_superadmin, only: %i[new create]

  def show
    project = visible_projects.find_by!(key: params[:id].to_s.upcase)
    redirect_to project_topics_path(project)
  end

  def new
    @project = Project.new(color: "orange", icon: "rocket")
  end

  def create
    @project = Project.new(params.expect(project: %i[name key description color icon]).merge(position: Project.count))
    @project.key = @project.name.to_s.gsub(/[^A-Za-z]/, "")[0, 3] if @project.key.blank?

    if @project.save
      @project.project_memberships.create!(user: Current.user, role: "admin")
      redirect_to project_topics_path(@project), notice: t("home.created", name: @project.name), status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  # Marks a project completed (it moves to the Completed tab) or brings it back.
  def update
    project = visible_projects.find_by!(key: params[:id].to_s.upcase)
    return render_error(403) unless project.managed_by?(Current.user)

    status = params.expect(project: [ :status ])[:status]
    return head :unprocessable_content unless Project.statuses.key?(status)

    project.update!(status: status)
    redirect_to(status == "completed" ? root_path : project_topics_path(project),
                notice: t(status == "completed" ? "home.completed" : "home.reactivated", name: project.name), status: :see_other)
  end

  def index
    @status = Project.statuses.key?(params[:status]) ? params[:status] : "active"
    @status_counts = visible_projects.group(:status).count
    @projects = visible_projects.where(status: @status).ordered.includes(:members)
    @open_topic_counts = Topic.open.where(project: @projects).group(:project_id).count
    @task_counts = Task.where(project: @projects).group(:project_id).count
    @waiting_count = Topic.awaiting_reply_from(Current.user).where(project: visible_projects).count
  end

  private

  def visible_projects = Project.visible_to(Current.user)
end
