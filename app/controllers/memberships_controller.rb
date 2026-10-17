# "People": a workspace admin's view of members and pending invitations.
class MembershipsController < ApplicationController
  layout "app"
  before_action :require_workspace_admin
  before_action :set_membership, only: %i[update destroy]

  def index
    @memberships = Current.workspace.memberships.includes(:user).order(:created_at)
    @invitations = Current.workspace.invitations.pending.includes(:invited_by).order(:created_at)
    @last_seen = Session.where(user_id: @memberships.map(&:user_id)).group(:user_id).maximum(:created_at)
  end

  def update
    if last_admin?(@membership) && params.expect(membership: [ :role ])[:role] != "admin"
      redirect_to memberships_path, alert: "A workspace needs at least one admin.", status: :see_other
    else
      @membership.update!(role: params.expect(membership: [ :role ])[:role])
      redirect_to memberships_path, notice: "#{@membership.user.short_name} is now #{@membership.role}.", status: :see_other
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to memberships_path, alert: "That role isn't available.", status: :see_other
  end

  # Removes access to this workspace. The person's account and what they wrote stay.
  def destroy
    return redirect_to memberships_path, alert: "A workspace needs at least one admin.", status: :see_other if last_admin?(@membership)

    Membership.transaction do
      ProjectMembership.joins(:project).where(user_id: @membership.user_id, projects: { workspace_id: Current.workspace.id }).destroy_all
      @membership.destroy!
    end
    redirect_to memberships_path, notice: "#{@membership.user.short_name} no longer has access.", status: :see_other
  end

  private

  def set_membership
    @membership = Current.workspace.memberships.find(params[:id])
  end

  def last_admin?(membership)
    membership.admin? && Current.workspace.memberships.admin.where.not(id: membership.id).none?
  end
end
