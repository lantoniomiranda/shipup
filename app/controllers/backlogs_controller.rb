class BacklogsController < ApplicationController
  include ProjectScoped

  def show
    @backlog = Backlog.new(project: @project, filter: params[:filter])
    @archived_tasks = @project.managed_by?(Current.user) ? @project.tasks.archived.order(archived_at: :desc).limit(20) : Task.none
  end
end
