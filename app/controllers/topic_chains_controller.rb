class TopicChainsController < ApplicationController
  include TopicScoped

  def new
    @chain = @project.chains.build(title: @topic.title, topic: @topic, sprint: @project.active_sprint)
    @steps = [ {}, {}, {} ]
    draft_with_ai if params[:draft] == "1"
  end

  def create
    @chain = Chain.create_with_steps!(project: @project, creator: Current.user, topic: @topic, title: chain_params[:title],
                                      sprint: @project.sprints.find_by(id: chain_params[:sprint_id]), steps: step_params)
    @topic.approve!
    redirect_to project_topic_path(@project, @topic), notice: t("chain_form.created", count: @chain.tasks.count)
  rescue ActiveRecord::RecordInvalid => error
    @chain = @project.chains.build(chain_params.slice(:title))
    @steps = step_params.presence || [ {} ]
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_content
  end

  private

  def draft_with_ai
    draft = Llm::Drafts.chain(@topic)
    @chain.title = draft.title
    @steps = draft.steps.map { |step| { title: step[:title], description: step[:description], estimate_days: step[:days] } }
    @drafted = true
  rescue Llm::Error => error
    Rails.logger.warn("AI chain draft failed: #{error.message}")
    @draft_error = error.is_a?(Llm::NotConfigured) ? t("ai.switched_off") : t("ai.failed", message: error.message.truncate(300))
    flash.now[:alert] = @draft_error
  end

  def chain_params
    params.expect(chain: %i[title sprint_id])
  end

  def step_params
    Array(params.dig(:chain, :steps)&.values).map { |step| step.permit(:title, :description, :assignee_id, :estimate_days).to_h.symbolize_keys }.map do |step|
      step.merge(assignee_id: @project.members.find_by(id: step[:assignee_id])&.id)
    end
  end
end
