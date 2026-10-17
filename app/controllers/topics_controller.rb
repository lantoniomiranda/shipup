class TopicsController < ApplicationController
  include ProjectScoped

  FILTERS = { "issues" => { kind: "issue" }, "features" => { kind: "feature" }, "canceled" => { status: "canceled" }, "approved" => { status: "approved" } }.freeze

  def index
    @filter = params[:filter] if FILTERS.key?(params[:filter])
    @sort = params[:sort] == "new" ? "new" : "top"
    scope = @project.topics.includes(:author, :client, tasks: :project, chains: { tasks: :project })
    scope = scope.where(FILTERS[@filter]) if @filter
    @topics = @sort == "new" ? scope.recent : scope.top
    @counts = { "issues" => @project.topics.issue.count, "features" => @project.topics.feature.count,
                "canceled" => @project.topics.canceled.count, "approved" => @project.topics.approved.count }
    @votes = TopicVote.where(user: Current.user, topic: @topics).index_by(&:topic_id)
  end

  def show
    @topic = @project.topics.includes(:author, :client).find(params[:id])
    @messages = @topic.messages.includes(:author, :parent).order(:created_at, :id)
    @vote = @topic.vote_by(Current.user)
    @participants = participants_of(@topic, @messages)
  end

  def new
    @topic = @project.topics.build(kind: params[:kind].presence_in(Topic::KINDS) || "feature")
  end

  def create
    @topic = @project.topics.build(topic_params.merge(author: Current.user, last_activity_at: Time.current))
    if @topic.save
      redirect_to project_topic_path(@project, @topic), notice: "Topic posted."
    else
      render :new, status: :unprocessable_content
    end
  end

  # Titles that read like what the user is typing, for the "Similar topics" side panel.
  def similar
    @query = params[:q].to_s.strip
    @similar = @query.length < 3 ? [] : @project.topics.similar_to(@query).limit(3)
    render layout: false
  end

  private

  def topic_params
    params.expect(topic: %i[kind title body client_id]).tap do |attrs|
      attrs[:client_id] = @project.clients.find_by(id: attrs[:client_id])&.id
    end
  end

  # The opener first, then everyone who replied, in order of first reply.
  def participants_of(topic, messages)
    repliers = messages.map(&:author).uniq - [ topic.author ]
    [ [ topic.author, "Opened" ] ] + repliers.map { |user| [ user, "Replied" ] }
  end
end
