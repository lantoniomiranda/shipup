class TimeOffRequestsController < ApplicationController
  layout "app"

  def index
    @month = month_from(params[:month])
    @people = Current.workspace.users.order(:name).to_a
    days = @month.beginning_of_month..@month.end_of_month
    @requests = TimeOffRequest.where(user: @people).overlapping(days).where.not(status: "declined").includes(:user).group_by(&:user_id)
    @mine = Current.user.time_off_requests.order(starts_on: :desc).limit(5)
    @to_approve = pending_for_approval
    @balances = TimeOffRequest::KINDS.index_with { |kind| TimeOffRequest.balance_for(Current.user, kind) }
  end

  def new
    @month = month_from(params[:month])
    @request = Current.user.time_off_requests.build(kind: "vacation")
    @approvers = approvers
    @away = away_by_day(@month)
  end

  def create
    attributes = params.expect(time_off_request: %i[kind starts_on ends_on])
    attributes[:ends_on] = attributes[:starts_on] if attributes[:ends_on].blank? # a single day
    @request = Current.user.time_off_requests.build(attributes)
    @request.approver = approvers.find { |user| user.id == params[:approver_id].to_i }

    if @request.save
      redirect_to time_off_requests_path, notice: "Request sent#{" to #{@request.approver.first_name}" if @request.approver}.", status: :see_other
    else
      @month = month_from(params[:month] || @request.starts_on&.strftime("%Y-%m"))
      @approvers = approvers
      @away = away_by_day(@month)
      flash.now[:alert] = @request.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    request = pending_for_approval.find(params[:id])
    request.decide!(by: Current.user, approve: params[:decision] == "approve")
    redirect_to time_off_requests_path, notice: "#{request.user.first_name}'s request #{request.status}.", status: :see_other
  end

  private

  def month_from(value)
    Date.strptime(value.to_s, "%Y-%m")
  rescue ArgumentError
    Date.current.beginning_of_month
  end

  def approvers
    Current.workspace.users.joins(:memberships).where(memberships: { workspace_id: Current.workspace.id, role: %w[admin manager] }).where.not(id: Current.user.id).order(:name).distinct
  end

  def pending_for_approval
    return TimeOffRequest.none unless %w[admin manager].include?(Current.user.role_in(Current.workspace))

    TimeOffRequest.pending.where(user: Current.workspace.users).where.not(user: Current.user).includes(:user).order(:starts_on)
  end

  # { Date => [[user, status], ...] } for teammates away during the month shown on the form.
  def away_by_day(month)
    range = month.beginning_of_month..month.end_of_month
    TimeOffRequest.where(user: Current.workspace.users).where.not(user: Current.user).where.not(status: "declined").overlapping(range).includes(:user)
                  .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |request, days|
      (request.starts_on..request.ends_on).each { |day| days[day] << [ request.user, request.status ] if range.cover?(day) && !day.on_weekend? }
    end
  end
end
