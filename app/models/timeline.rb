# A planning timeline: one row per feature (a topic's tasks) or loose task, with its steps scheduled
# back to back. Dates are derived from estimates (working days) since tasks carry no start date.
class Timeline
  Bar = Data.define(:label, :title, :task, :starts_on, :ends_on, :state) # state: done | in_progress | planned | risk
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

  # Features with at least one bar inside the window, capped at MAX_ROWS (see #hidden_rows).
  def rows
    @rows ||= all_rows.first(MAX_ROWS)
  end

  def hidden_rows = [ all_rows.size - MAX_ROWS, 0 ].max

  def scheduled_tasks? = groups.any?

  def current_window? = range.cover?(today)

  def meetings
    @meetings ||= Meeting.where(topic: project.topics).where(starts_at: range.first.beginning_of_day..(range.end - 1).end_of_day).includes(:topic).order(:starts_at)
  end

  # Meetings grouped by day for the chips row: { Date => [Meeting] }.
  def meetings_by_day
    meetings.group_by { |meeting| meeting.starts_at.to_date }
  end

  # The first working day on or after +date+.
  def self.next_working_day(date)
    date += 1 until date.on_weekday?
    date
  end

  def self.add_working_days(date, count)
    date = next_working_day(date)
    (count - 1).times do
      date += 1
      date += 1 until date.on_weekday?
    end
    date
  end

  private

  # The window always opens on the week containing today, so the today marker is in view.
  def default_start = today

  def all_rows
    @all_rows ||= groups.map { |title, tasks| build_row(title, tasks) }.select { |row| row.bars.any? { |bar| visible?(bar) } }
  end

  def visible?(bar) = bar.ends_on >= range.first && bar.starts_on < range.end

  # [title, [tasks]] — tasks of one topic form a feature; topic-less tasks stand alone.
  def groups
    @groups ||= build_groups
  end

  def build_groups
    tasks = project.tasks.where.not(sprint_id: nil).includes(:topic, :chain, :labels, :sprint).order(:chain_position, :number).to_a
    by_topic, loose = tasks.partition(&:topic_id)
    by_topic.group_by(&:topic).map { |topic, list| [ topic.title, list ] } + loose.map { |task| [ task.title, [ task ] ] }
  end

  def build_row(title, tasks)
    cursor = tasks.filter_map { |task| task.sprint&.starts_on }.min || today
    bars = tasks.map do |task|
      duration = [ (task.estimate_days || 1).ceil, 1 ].max
      starts_on = self.class.next_working_day(task.done? ? cursor : [ cursor, today ].max)
      ends_on = self.class.add_working_days(starts_on, duration)
      cursor = ends_on + 1
      Bar.new(label: task.labels.first&.name || task.title.split.first, title: "#{task.key} #{task.title}", task: task,
              starts_on: starts_on, ends_on: ends_on, state: state_for(task, ends_on))
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
