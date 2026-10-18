# "People" tab: who is on the project and who has been invited. Everyone on the project can see it;
# admins and the project's admins invite, change roles and remove people.
class ProjectMembersController < ApplicationController
  include ProjectScoped
  before_action :require_project_admin, only: %i[update destroy]
  before_action :set_membership, only: %i[update destroy]

  def index
    @memberships = @project.project_memberships.includes(:user).order(:created_at)
    @invitations = @project.invitations.pending.includes(:invited_by).order(:created_at)
    @last_seen = Session.where(user_id: @memberships.map(&:user_id)).group(:user_id).maximum(:created_at)
  end

  def update
    @membership.update!(role: params.expect(project_membership: [ :role ])[:role])
    redirect_to project_members_path(@project), notice: t("people.now_role", name: @membership.user.short_name, role: t("roles.#{@membership.role}")), status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to project_members_path(@project), alert: t("people.bad_role"), status: :see_other
  end

  # Takes the person off the project. Their account and what they wrote stay.
  def destroy
    return redirect_to project_members_path(@project), alert: t("people.not_self"), status: :see_other if @membership.user == Current.user

    @membership.destroy!
    redirect_to project_members_path(@project), notice: t("people.removed", name: @membership.user.short_name, project: @project.name), status: :see_other
  end

  private

  def set_membership
    @membership = @project.project_memberships.find(params[:id])
  end
end
