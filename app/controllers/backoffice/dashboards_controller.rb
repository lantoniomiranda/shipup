class Backoffice::DashboardsController < Backoffice::BaseController
  def show
    @status_counts = Workspace.group(:status).count
    @plan_counts = Workspace.group(:plan).count
    @users_count = User.count
    @projects_count = Project.count
    @tasks_count = Task.count
    @recent = Workspace.order(created_at: :desc).limit(5)
    @ending_trials = Workspace.plan_trial.active.where(trial_ends_at: ..7.days.from_now).order(:trial_ends_at).limit(5)
    @pending_invitations = Invitation.pending.count
  end
end
