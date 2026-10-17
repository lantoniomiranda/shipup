class BacklogsController < ApplicationController
  include ProjectScoped

  def show
    @backlog = Backlog.new(project: @project, filter: params[:filter])
  end

  # Creates the sprint after the last one so there is somewhere to plan into.
  def plan_sprint
    return redirect_to project_backlog_path(@project), alert: "A sprint is already planned." if Backlog.new(project: @project).sprint

    last = @project.sprints.order(:number).last
    starts_on = [ (last&.ends_on || Date.current - 1) + 1, Date.current + 1 ].max
    sprint = @project.sprints.create!(number: (last&.number || 0) + 1, starts_on: starts_on, ends_on: starts_on + 13)
    redirect_to project_backlog_path(@project), notice: "#{sprint.name} is ready to plan.", status: :see_other
  end
end
