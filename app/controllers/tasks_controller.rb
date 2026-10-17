class TasksController < ApplicationController
  include ProjectScoped
  before_action :set_task

  def show
    @entries = @task.time_entries.includes(:user).order(started_at: :desc).limit(5)
    @running_entry = Current.user.running_time_entry
    @siblings = @project.tasks.where(sprint: @task.sprint).unlocked.order(:position, :number).pluck(:number)
  end

  # Board drag-and-drop and the status keys both land here.
  def update
    status = params.dig(:task, :status)
    return head :unprocessable_content unless Task::STATUSES.include?(status)

    @task.move_to!(status)
    redirect_to project_board_path(@project), notice: "#{@task.key} moved to #{Board::LABELS.fetch(status)}", status: :see_other
  end

  # Finishes this step; if it was part of a chain the next step unlocks on the board.
  def advance
    @task.move_to!(@task.next_status || "done")
    next_step = @task.next_in_chain
    notice = @task.done? && next_step ? "#{@task.key} done. #{next_step.title} is now unlocked." : "#{@task.key} moved to #{Board::LABELS.fetch(@task.status)}"
    redirect_back_or_to project_board_path(@project), notice: notice, status: :see_other
  end

  private

  def set_task
    @task = @project.tasks.includes(:assignee, :creator, :client, :sprint, :topic, :labels, :pull_requests, chain: { tasks: %i[assignee pull_requests] })
                    .find_by!(number: params[:id])
  end
end
