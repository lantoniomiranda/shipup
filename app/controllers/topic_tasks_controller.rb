class TopicTasksController < ApplicationController
  include TopicScoped

  def new
    @task = @project.tasks.build(title: @topic.title, description: @topic.body, topic: @topic, sprint: @project.active_sprint,
                                 bug: @topic.issue?, client: @topic.client, assignee: Current.user)
  end

  def create
    @task = @project.tasks.build(task_params.merge(creator: Current.user, topic: @topic))
    if @task.save
      @topic.approve!
      redirect_to project_topic_path(@project, @topic), notice: "#{@task.key} created from this topic."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def task_params
    params.expect(task: [ :title, :description, :assignee_id, :estimate_days, :due_on, :sprint_id, :bug, :client_id, { label_ids: [] } ]).tap do |attrs|
      attrs[:assignee_id] = @project.members.find_by(id: attrs[:assignee_id])&.id
      attrs[:sprint_id] = @project.sprints.find_by(id: attrs[:sprint_id])&.id
      attrs[:client_id] = @project.clients.find_by(id: attrs[:client_id])&.id
      attrs[:label_ids] = @project.labels.where(id: Array(attrs[:label_ids])).ids
    end
  end
end
