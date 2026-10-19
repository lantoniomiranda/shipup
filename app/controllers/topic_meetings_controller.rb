class TopicMeetingsController < ApplicationController
  include TopicScoped

  def new
    @invitees = invitable_people
    @slots = MeetingSlots.suggest(@invitees.map(&:first))
    @default_start = (@slots.first&.starts_at || 1.day.from_now.change(hour: 14)).in_time_zone
  end

  def create
    starts_at = requested_start
    return redirect_to(new_project_topic_meeting_path(@project, @topic), alert: t("meetings.future")) if starts_at <= Time.current

    meeting = @topic.meetings.build(organizer: Current.user, provider: Setting.meeting_provider.to_s,
                                    starts_at: starts_at, duration_minutes: params[:duration_minutes].to_i,
                                    transcribe: params[:transcribe] == "1")
    Meeting.transaction do
      meeting.save!
      attendee_ids.each { |id, requirement| meeting.participants.create!(user_id: id, requirement: requirement) }
      meeting.provision!
    end
    redirect_to project_topic_path(@project, @topic), notice: t("meetings.posted")
  rescue Integrations::NotConnected
    redirect_to new_project_topic_meeting_path(@project, @topic), alert: t("meetings.need_tool")
  rescue Integrations::Error, ActiveRecord::RecordInvalid, ArgumentError => error
    Rails.logger.warn("Meeting creation failed: #{error.message}")
    redirect_to new_project_topic_meeting_path(@project, @topic), alert: t("meetings.failed")
  end

  private

  # The date and time the organizer picked, read in their own time zone (the request already runs in
  # it). An ISO8601 `starts_at` is still accepted for integrations and scripts.
  def requested_start
    return Time.iso8601(params[:starts_at].to_s) if params[:date].blank?

    Time.zone.parse("#{params[:date]} #{params[:time].presence || "09:00"}") || raise(ArgumentError, "unreadable date or time")
  end

  # People in this topic first, then the rest of the project team. Value is the reason shown under their name.
  def invitable_people
    in_topic = ([ @topic.author ] + @topic.messages.includes(:author).map(&:author)).uniq
    others = @project.members.where.not(id: in_topic.map(&:id)).order(:name)
    in_topic.map { |user| [ user, user == @topic.author ? t("meetings.opened") : t("meetings.replied") ] } + others.map { |user| [ user, t("meetings.not_in_topic") ] }
  end

  # { user_id => "required" | "optional" } for every ticked invitee that belongs to the project.
  def attendee_ids
    allowed = @project.members.ids.map(&:to_s)
    params.fetch(:attendees, {}).to_unsafe_h.select { |id, attrs| allowed.include?(id) && attrs["invite"] == "1" }
          .transform_values { |attrs| attrs["requirement"] == "optional" ? "optional" : "required" }
  end
end
