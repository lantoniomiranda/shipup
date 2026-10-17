class TopicMessagesController < ApplicationController
  include ChatMessages

  private

  def set_chat_thread
    @topic = @project.topics.find(params[:topic_id])
  end

  def chat_thread = @topic
  def chat_path(**options) = project_topic_path(@project, @topic, **options)
end
