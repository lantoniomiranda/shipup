class ProjectClientsController < ApplicationController
  include ProjectScoped

  FILTERS = %w[active invite_pending].freeze

  def index
    @filter = params[:filter].presence_in(FILTERS)
    scope = @project.project_clients.includes(client: :contacts)
    @counts = scope.group(:status).count
    @project_clients = (@filter ? scope.where(status: @filter) : scope).order(created_at: :desc)
    @topic_counts = @project.topics.where.not(client_id: nil).group(:client_id).count
    @last_activity = @project.topics.where.not(client_id: nil).group(:client_id).maximum(:created_at)
  end

  def new
    @clients = @project.clients.order(:name)
  end

  def create
    client = Client.onboard!(workspace: Current.workspace, name: params[:company], contact_name: params[:contact_name], emails: Array(params[:emails]))
    @project.project_clients.find_or_create_by!(client: client)
    redirect_to project_clients_path(@project), notice: "#{client.name} added. They'll get an invite by email.", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @clients = @project.clients.order(:name)
    flash.now[:alert] = error.record.errors.full_messages.to_sentence.presence || "Please fill in the company and contact."
    render :new, status: :unprocessable_content
  end
end
