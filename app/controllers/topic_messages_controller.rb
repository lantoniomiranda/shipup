class TopicMessagesController < ApplicationController
  include ProjectScoped

  def create
    topic = @project.topics.find(params[:topic_id])
    message = topic.messages.build(author: Current.user, body: params.expect(message: [ :body ])[:body])

    if message.save
      redirect_to project_topic_path(@project, topic, anchor: "message-#{message.id}"), status: :see_other
    else
      redirect_to project_topic_path(@project, topic), alert: "Write something before sending.", status: :see_other
    end
  end
end
