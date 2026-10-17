class TaskMessagesController < ApplicationController
  include ChatMessages

  private

  def set_chat_thread
    @task = @project.tasks.find_by!(number: params[:task_id])
  end

  def chat_thread = @task
  def chat_path(**options) = project_task_path(@project, @task, **options)
end
