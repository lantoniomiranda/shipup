class TopicsController < ApplicationController
  include ProjectScoped
  before_action :set_topic_for_status_change, only: %i[cancel reopen]

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
      redirect_to project_topic_path(@project, @topic), notice: t("topics.posted")
    else
      render :new, status: :unprocessable_content
    end
  end

  # Drops a topic nobody will act on. The reason (optional) is posted in its thread.
  def cancel
    Topic.transaction do
      @topic.cancel!
      reason = params[:reason].to_s.strip
      body = reason.present? ? t("topics.cancel_with_reason", reason: reason) : t("topics.cancel_without_reason")
      @topic.messages.create!(author: Current.user, body: body)
    end
    redirect_to project_topic_path(@project, @topic), notice: t("topics.canceled"), status: :see_other
  end

  def reopen
    Topic.transaction do
      @topic.reopen!
      @topic.messages.create!(author: Current.user, body: "Reopened this topic.")
    end
    redirect_to project_topic_path(@project, @topic), notice: t("topics.reopened"), status: :see_other
  end

  # Titles that read like what the user is typing, for the "Similar topics" side panel.
  def similar
    @query = params[:q].to_s.strip
    @similar = @query.length < 3 ? [] : @project.topics.similar_to(@query).limit(3)
    render layout: false
  end

  private

  # The person who opened a topic and the project's admins may cancel or reopen it.
  def set_topic_for_status_change
    @topic = @project.topics.find(params[:id])
    render_error(403) unless @topic.author == Current.user || @project.managed_by?(Current.user)
  end

  def topic_params
    params.expect(topic: %i[kind title body client_id]).tap do |attrs|
      attrs[:client_id] = @project.clients.active.find_by(id: attrs[:client_id])&.id
    end
  end

  # The opener first, then everyone who replied, in order of first reply.
  def participants_of(topic, messages)
    repliers = messages.map(&:author).uniq - [ topic.author ]
    [ [ topic.author, t("topics.roles.opened") ] ] + repliers.map { |user| [ user, t("topics.roles.replied") ] }
  end
end
