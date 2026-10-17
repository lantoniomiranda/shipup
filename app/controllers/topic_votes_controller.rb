class TopicVotesController < ApplicationController
  include ProjectScoped

  def create
    topic = @project.topics.find(params[:topic_id])
    topic.cast_vote(Current.user, params[:value].to_i.clamp(-1, 1).nonzero? || 1)
    redirect_back_or_to project_topics_path(@project), status: :see_other
  end
end
