# Start / stop the signed-in user's timer on a task. Only one timer runs at a time.
class TaskTimersController < ApplicationController
  include ProjectScoped

  def create
    task = @project.tasks.find_by!(number: params[:task_id])
    TimeEntry.transaction do
      Current.user.running_time_entry&.stop!
      task.time_entries.create!(user: Current.user, started_at: Time.current)
    end
    redirect_back_or_to project_task_path(@project, task), notice: "Timer started on #{task.key}.", status: :see_other
  end

  def destroy
    task = @project.tasks.find_by!(number: params[:task_id])
    Current.user.time_entries.running.where(task: task).find_each(&:stop!)
    redirect_back_or_to project_task_path(@project, task), notice: "Timer stopped.", status: :see_other
  end
end
