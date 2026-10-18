class TopicTasksController < ApplicationController
  include TopicScoped

  def new
    @task = @project.tasks.build(title: @topic.title, description: @topic.body, topic: @topic, sprint: @project.active_sprint,
                                 bug: @topic.issue?, client: @topic.client, assignee: Current.user)
    draft_with_ai if params[:draft] == "1"
  end

  def create
    @task = @project.tasks.build(task_params.merge(creator: Current.user, topic: @topic))
    if @task.save
      @topic.approve!
      redirect_to project_topic_path(@project, @topic), notice: t("tasks.created", key: @task.key)
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  # Replaces the prefilled title/description with an AI draft built from the discussion.
  def draft_with_ai
    draft = Llm::Drafts.task(@topic)
    @task.assign_attributes(title: draft.title, description: draft.description)
    @drafted = true
  rescue Llm::Error => error
    Rails.logger.warn("AI task draft failed: #{error.message}")
    @draft_error = error.is_a?(Llm::NotConfigured) ? "AI drafts are switched off. Set LLM_ENABLED and LLM_API_KEY." : "The AI draft failed: #{error.message.truncate(300)}"
    flash.now[:alert] = @draft_error
  end

  def task_params
    params.expect(task: [ :title, :description, :assignee_id, :estimate_days, :due_on, :sprint_id, :bug, :client_id, { label_ids: [] } ]).tap do |attrs|
      attrs[:assignee_id] = @project.members.find_by(id: attrs[:assignee_id])&.id
      attrs[:sprint_id] = @project.sprints.find_by(id: attrs[:sprint_id])&.id
      attrs[:client_id] = @project.clients.active.find_by(id: attrs[:client_id])&.id
      attrs[:label_ids] = @project.labels.where(id: Array(attrs[:label_ids])).ids
    end
  end
end
