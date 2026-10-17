class ProjectsController < ApplicationController
  layout "app"

  def show
    project = Current.workspace.projects.find_by!(key: params[:id].to_s.upcase)
    redirect_to project_topics_path(project)
  end

  def index
    @status = Project.statuses.key?(params[:status]) ? params[:status] : "active"
    @status_counts = Current.workspace.projects.group(:status).count
    @projects = Current.workspace.projects.where(status: @status).ordered.includes(:members)
    @open_topic_counts = Topic.open.where(project: @projects).group(:project_id).count
    @task_counts = Task.where(project: @projects).group(:project_id).count
    @waiting_count = Topic.awaiting_reply_from(Current.user).where(project: Current.workspace.projects).count
  end
end
