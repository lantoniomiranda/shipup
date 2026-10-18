class ProjectClientsController < ApplicationController
  include ProjectScoped
  before_action :require_project_admin, only: %i[destroy restore]

  FILTERS = %w[active invite_pending archived].freeze

  def index
    @filter = params[:filter].presence_in(FILTERS)
    scope = @project.project_clients.joins(:client).includes(client: :contacts)
    visible = @filter == "archived" ? scope.merge(Client.archived) : scope.merge(Client.active)
    @counts = scope.merge(Client.active).group(:status).count
    @archived_count = scope.merge(Client.archived).count
    @project_clients = (%w[active invite_pending].include?(@filter) ? visible.where(status: @filter) : visible).order(created_at: :desc)
    @topic_counts = @project.topics.where.not(client_id: nil).group(:client_id).count
    @last_activity = @project.topics.where.not(client_id: nil).group(:client_id).maximum(:created_at)
  end

  def new
    @clients = @project.clients.active.order(:name)
  end

  def create
    client = Client.onboard!(name: params[:company], contact_name: params[:contact_name], emails: Array(params[:emails]))
    @project.project_clients.find_or_create_by!(client: client)
    redirect_to project_clients_path(@project), notice: t("clients.added_flash", name: client.name), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @clients = @project.clients.active.order(:name)
    flash.now[:alert] = error.record.errors.full_messages.to_sentence.presence || "Please fill in the company and contact."
    render :new, status: :unprocessable_content
  end

  # Soft delete: the client is archived everywhere, its topics keep their history.
  def destroy
    client = @project.clients.find(params[:id])
    client.archive!
    redirect_to project_clients_path(@project), notice: t("clients.archived_flash", name: client.name), status: :see_other
  end

  def restore
    client = @project.clients.find(params[:id])
    client.restore!
    redirect_to project_clients_path(@project), notice: t("clients.restored_flash", name: client.name), status: :see_other
  end
end
