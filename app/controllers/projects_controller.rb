class ProjectsController < ApplicationController
  layout "app"

  def show
    project = Current.workspace.projects.find_by!(key: params[:id].to_s.upcase)
    redirect_to project_topics_path(project)
  end

  def new
    return head :forbidden unless workspace_admin?

    @project = Current.workspace.projects.build(color: "orange", icon: "rocket")
  end

  def create
    return head :forbidden unless workspace_admin?

    @project = Current.workspace.projects.build(params.expect(project: %i[name key description color icon]).merge(position: Current.workspace.projects.count))
    @project.key = @project.name.to_s.gsub(/[^A-Za-z]/, "")[0, 3] if @project.key.blank?

    if @project.save
      @project.project_memberships.create!(user: Current.user, role: "manager")
      redirect_to project_topics_path(@project), notice: "#{@project.name} created.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def index
    @status = Project.statuses.key?(params[:status]) ? params[:status] : "active"
    @status_counts = Current.workspace.projects.group(:status).count
    @projects = Current.workspace.projects.where(status: @status).ordered.includes(:members)
    @open_topic_counts = Topic.open.where(project: @projects).group(:project_id).count
    @task_counts = Task.where(project: @projects).group(:project_id).count
    @waiting_count = Topic.awaiting_reply_from(Current.user).where(project: Current.workspace.projects).count
  end

  private

  def workspace_admin?
    Current.user.role_in(Current.workspace) == "admin"
  end
end
