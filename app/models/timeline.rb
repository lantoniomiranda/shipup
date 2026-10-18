# A planning timeline: one row per feature (a topic's tasks) or loose task, with its steps scheduled
# back to back. Dates are derived from estimates (working days) since tasks carry no start date.
class Timeline
  Bar = Data.define(:label, :starts_on, :ends_on, :state) # state: done | in_progress | planned | risk
  Row = Data.define(:title, :subtitle, :percent, :bars, :due_on)
  Band = Data.define(:sprint, :starts_on, :ends_on)

  WEEKS = 8
  MAX_ROWS = 12

  attr_reader :project, :from, :today

  def initialize(project:, from: nil, today: Date.current)
    @project = project
    @today = today
    @from = (from || default_start).beginning_of_week
  end

  def range = from...(from + WEEKS.weeks)
  def days = range.to_a
  def weeks = range.step(7).to_a

  def bands
    project.sprints.where("ends_on >= ? AND starts_on < ?", range.first, range.end).order(:starts_on).map do |sprint|
      Band.new(sprint: sprint, starts_on: [ sprint.starts_on, range.first ].max, ends_on: [ sprint.ends_on, range.end - 1 ].min)
    end
  end

  def rows
    @rows ||= groups.first(MAX_ROWS).map { |title, tasks| build_row(title, tasks) }
  end

  def meetings
    @meetings ||= Meeting.where(topic: project.topics).where(starts_at: range.first.beginning_of_day..(range.end - 1).end_of_day).includes(:topic).order(:starts_at)
  end

  # Meetings grouped by day for the chips row: { Date => [Meeting] }.
  def meetings_by_day
    meetings.group_by { |meeting| meeting.starts_at.to_date }
  end

  def self.add_working_days(date, count)
    date += 1 until date.on_weekday?
    (count - 1).times do
      date += 1
      date += 1 until date.on_weekday?
    end
    date
  end

  private

  def default_start
    project.active_sprint&.starts_on || today
  end

  # [title, [tasks]] — tasks of one topic form a feature; topic-less tasks stand alone.
  def groups
    tasks = project.tasks.where.not(sprint_id: nil).includes(:topic, :chain, :labels, :sprint).order(:chain_position, :number).to_a
    by_topic, loose = tasks.partition(&:topic_id)
    by_topic.group_by(&:topic).map { |topic, list| [ topic.title, list ] } + loose.map { |task| [ task.title, [ task ] ] }
  end

  def build_row(title, tasks)
    cursor = [ tasks.filter_map { |task| task.sprint&.starts_on }.min || today, range.first ].max
    bars = tasks.map do |task|
      duration = [ (task.estimate_days || 1).ceil, 1 ].max
      starts_on = task.done? ? cursor : [ cursor, today ].max
      ends_on = self.class.add_working_days(starts_on, duration)
      cursor = ends_on + 1
      Bar.new(label: task.labels.first&.name || task.title.split.first, starts_on: starts_on, ends_on: ends_on, state: state_for(task, ends_on))
    end
    percent = tasks.empty? ? 0 : (tasks.count(&:done?) * 100.0 / tasks.size).round
    first = tasks.first
    Row.new(title: title, subtitle: I18n.t("timeline.row_subtitle", key: first.key, done: tasks.count(&:done?), count: tasks.size),
            percent: percent, bars: bars, due_on: tasks.filter_map(&:due_on).max || bars.last&.ends_on)
  end

  def state_for(task, ends_on)
    return :done if task.done?
    return :risk if task.due_on && ends_on > task.due_on

    task.in_progress? || task.testing? || task.ready_to_deploy? ? :in_progress : :planned
  end
end
