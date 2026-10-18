# Create, start and complete sprints. A project has one active sprint at a time and the
# board always shows it.
class SprintsController < ApplicationController
  include ProjectScoped
  before_action :require_manager
  before_action :set_sprint, only: %i[start complete]

  def new
    @sprint = Sprint.next_for(@project)
  end

  def create
    @sprint = @project.sprints.new(sprint_params)
    @sprint.number = (@project.sprints.maximum(:number) || 0) + 1

    Sprint.transaction do
      @sprint.save!
      @sprint.start!(carry_over: carry_over?) if params[:start_now] == "1"
    end
    redirect_to @sprint.active? ? project_board_path(@project) : project_backlog_path(@project),
                notice: @sprint.active? ? t("sprints.started", name: @sprint.name) : t("sprints.planned", name: @sprint.name), status: :see_other
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  def start
    return redirect_to project_backlog_path(@project), alert: t("sprints.cannot_start") unless @sprint.planned?

    @sprint.start!(carry_over: carry_over?)
    redirect_to project_board_path(@project), notice: t("sprints.started", name: @sprint.name), status: :see_other
  end

  def complete
    return redirect_to project_board_path(@project), alert: t("sprints.only_active") unless @sprint.active?

    @sprint.complete!(carry_over_to: @project.sprints.upcoming.first)
    redirect_to project_backlog_path(@project), notice: t("sprints.completed", name: @sprint.name), status: :see_other
  end

  private

  def sprint_params
    params.expect(sprint: %i[goal starts_on ends_on])
  end

  def carry_over?
    params[:carry_over] != "0"
  end

  def set_sprint
    @sprint = @project.sprints.find(params[:id])
  end

  def require_manager
    render_error(403) unless @project.managed_by?(Current.user)
  end
end
