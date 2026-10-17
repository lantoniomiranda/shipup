# Project analytics for a period: topic flow, hours logged and meetings.
class Analytics
  RANGES = %w[eight_weeks sprint quarter].freeze
  LABELS = { "eight_weeks" => "Last 8 weeks", "sprint" => "This sprint", "quarter" => "Quarter" }.freeze
  Week = Data.define(:label, :opened, :approved, :canceled, :hours)

  attr_reader :project, :range_key

  def initialize(project:, range: nil, today: Date.current)
    @project = project
    @today = today
    @range_key = range.presence_in(RANGES) || "eight_weeks"
  end

  def period
    @period ||= case range_key
    when "sprint" then (project.active_sprint&.starts_on || @today - 13)..@today
    when "quarter" then @today.beginning_of_quarter..@today
    else (@today - 8.weeks + 1)..@today
    end
  end

  def previous_period
    length = (period.end - period.begin).to_i + 1
    (period.begin - length)..(period.begin - 1)
  end

  def topics_count = topics_in(period).count
  def topics_delta = topics_count - topics_in(previous_period).count
  def hours_logged = (entries_in(period).sum { |entry| entry.seconds } / 3600.0).round
  def deployed_items = project.tasks.where(status: "done", completed_at: bounds(period)).count

  def meetings
    @meetings ||= Meeting.where(topic: project.topics, starts_at: bounds(period)).includes(:participants, :topic).to_a
  end

  def meeting_minutes = meetings.sum(&:duration_minutes)
  def decided_meetings = meetings.count { |meeting| !meeting.topic.open? }
  def average_invited = meetings.empty? ? 0 : (meetings.sum { |meeting| meeting.participants.size } / meetings.size.to_f).round(1)

  def weeks
    @weeks ||= week_starts.map do |start|
      finish = start + 6
      scoped = topics_in(start..finish)
      Week.new(label: "W#{start.cweek}", opened: scoped.count, approved: scoped.count(&:approved?), canceled: scoped.count(&:canceled?),
               hours: (entries_in(start..finish).sum(&:seconds) / 3600.0).round(1))
    end
  end

  def max_topics = [ weeks.map { |week| [ week.opened, week.approved, week.canceled ].max }.max.to_i, 1 ].max
  def max_hours = [ weeks.map(&:hours).max.to_f, 1 ].max

  def closed_topics
    project.topics.where.not(status: "open").where(created_at: bounds(period)).order(created_at: :desc).limit(8)
  end

  private

  def week_starts
    first = period.begin.beginning_of_week
    (first..period.end).step(7).to_a.last(8)
  end

  def bounds(range) = range.begin.beginning_of_day..range.end.end_of_day

  def topics_in(range)
    @topic_cache ||= project.topics.where(created_at: previous_period.begin.beginning_of_day..period.end.end_of_day).to_a
    @topic_cache.select { |topic| range.cover?(topic.created_at.to_date) }
  end

  def entries_in(range)
    @entry_cache ||= TimeEntry.joins(:task).where(tasks: { project_id: project.id }).where(started_at: (period.begin - 8.weeks).beginning_of_day..period.end.end_of_day).to_a
    @entry_cache.select { |entry| range.cover?(entry.started_at.to_date) }
  end
end
