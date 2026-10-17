# Controllers for things made *from* a topic (tasks, chains, meetings).
module TopicScoped
  extend ActiveSupport::Concern

  included do
    include ProjectScoped
    before_action :set_topic
  end

  private

  def set_topic
    @topic = @project.topics.find(params[:topic_id])
  end
end
