# Tenant management: list, onboard (which invites the first admin), edit plan and seats,
# suspend and reactivate.
class Backoffice::WorkspacesController < Backoffice::BaseController
  before_action :set_workspace, only: %i[show edit update suspend reactivate]

  def index
    @status = params[:status].presence_in(Workspace::STATUSES)
    @plan = params[:plan].presence_in(Workspace::PLANS)
    scope = Workspace.search(params[:q]).order(created_at: :desc)
    scope = scope.where(status: @status) if @status
    scope = scope.where(plan: @plan) if @plan
    @workspaces = scope.to_a
    ids = @workspaces.map(&:id)
    @member_counts = Membership.where(workspace_id: ids).group(:workspace_id).count
    @project_counts = Project.where(workspace_id: ids).group(:workspace_id).count
    @last_seen = Session.joins(user: :memberships).where(memberships: { workspace_id: ids }).group("memberships.workspace_id").maximum("sessions.created_at")
  end

  def show
    @memberships = @workspace.memberships.includes(:user).order(:created_at)
    @invitations = @workspace.invitations.pending.includes(:invited_by).order(:created_at)
    @usage = { projects: @workspace.projects.count, topics: Topic.where(project: @workspace.projects).count,
               tasks: Task.where(project: @workspace.projects).count, meetings: Meeting.where(topic: Topic.where(project: @workspace.projects)).count }
    @last_seen = Session.joins(user: :memberships).where(memberships: { workspace_id: @workspace.id }).maximum(:created_at)
  end

  def new
    @workspace = Workspace.new(plan: "trial", seats_limit: 10)
  end

  def create
    @workspace = Workspace.provision!(**provision_params)
    invitation = @workspace.invitations.first
    InvitationMailer.invite(invitation).deliver_later
    redirect_to backoffice_tenant_path(@workspace), notice: "#{@workspace.name} created. An invitation went to #{invitation.email}.", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @workspace = Workspace.new(workspace_settings.slice(:name, :slug, :plan, :seats_limit, :email_domain, :allow_domain_join))
    @workspace.errors.merge!(error.record.errors)
    @admin_email = workspace_settings[:admin_email]
    render :new, status: :unprocessable_content
  end

  def edit; end

  def update
    if @workspace.update(workspace_settings.except(:admin_email))
      redirect_to backoffice_tenant_path(@workspace), notice: "Saved.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def suspend
    @workspace.suspend!(params[:reason])
    redirect_to backoffice_tenant_path(@workspace), notice: "#{@workspace.name} is suspended. Its members can no longer use ohship.", status: :see_other
  end

  def reactivate
    @workspace.reactivate!
    redirect_to backoffice_tenant_path(@workspace), notice: "#{@workspace.name} is active again.", status: :see_other
  end

  private

  def set_workspace
    @workspace = Workspace.find(params[:id])
  end

  def workspace_settings
    params.expect(workspace: %i[name slug plan seats_limit email_domain allow_domain_join admin_email trial_days]).to_h.symbolize_keys
  end

  def provision_params
    settings = workspace_settings
    { name: settings[:name], admin_email: settings[:admin_email], plan: settings[:plan].presence || "trial", seats_limit: settings[:seats_limit].presence,
      invited_by: Current.user, trial_days: (settings[:trial_days].presence || Workspace::TRIAL_DAYS).to_i,
      slug: settings[:slug].presence, email_domain: settings[:email_domain].presence,
      allow_domain_join: ActiveModel::Type::Boolean.new.cast(settings[:allow_domain_join]) || false }.reject { |_key, value| value.nil? }
  end
end
