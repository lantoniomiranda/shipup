class TasksController < ApplicationController
  include ProjectScoped
  before_action :set_task, except: :restore
  before_action :require_project_admin, only: %i[archive restore]

  def show
    @messages = @task.messages.includes(:author, :parent).order(:created_at, :id)
    @entries = @task.time_entries.includes(:user).order(started_at: :desc).limit(5)
    @running_entry = Current.user.running_time_entry
    @siblings = @project.tasks.where(sprint: @task.sprint).unlocked.order(:position, :number).pluck(:number)
  end

  # Board drag-and-drop and the status keys both land here.
  def update
    status = params.dig(:task, :status)
    return head :unprocessable_content unless Task::STATUSES.include?(status)

    @task.move_to!(status)
    redirect_to project_board_path(@project), notice: t("tasks.moved_status", key: @task.key, status: Board.status_label(status)), status: :see_other
  end

  # Backlog: put the task into the next sprint, or send it back to the backlog.
  def schedule
    sprint = params[:to] == "sprint" ? Backlog.new(project: @project).sprint : nil
    return redirect_to project_backlog_path(@project), alert: t("tasks.plan_first"), status: :see_other if params[:to] == "sprint" && sprint.nil?

    @task.update!(sprint: sprint)
    notice = sprint ? t("tasks.moved_sprint", key: @task.key, sprint: sprint.name) : t("tasks.moved_backlog", key: @task.key)
    redirect_to project_backlog_path(@project), notice: notice, status: :see_other
  end

  # Finishes this step; if it was part of a chain the next step unlocks on the board.
  def advance
    @task.move_to!(@task.next_status || "done")
    next_step = @task.next_in_chain
    notice = @task.done? && next_step ? t("tasks.unlocked", key: @task.key, title: next_step.title) : t("tasks.moved_status", key: @task.key, status: Board.status_label(@task.status))
    redirect_back_or_to project_board_path(@project), notice: notice, status: :see_other
  end

  # Soft delete: the task leaves the board and backlog but keeps its history; project admins can restore it.
  def archive
    @task.archive!
    redirect_to project_backlog_path(@project), notice: t("tasks.archived", key: @task.key), status: :see_other
  end

  def restore
    task = @project.tasks.archived.find_by!(number: params[:id])
    task.restore!
    redirect_to project_backlog_path(@project), notice: t("tasks.restored", key: task.key), status: :see_other
  end

  private

  def set_task
    @task = @project.tasks.includes(:assignee, :creator, :client, :sprint, :topic, :labels, :pull_requests, chain: { tasks: %i[assignee pull_requests] })
                    .find_by!(number: params[:id])
  end
end
