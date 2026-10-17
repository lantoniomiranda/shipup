# Sprint planning view: the next sprint's tasks, the unscheduled backlog, and team capacity.
# One XP is one estimated working day.
class Backlog
  DAYS_PER_PERSON = 10 # working days in a two-week sprint
  FILTERS = %w[chains unassigned unestimated].freeze

  attr_reader :project, :sprint, :filter

  def initialize(project:, filter: nil, today: Date.current)
    @project = project
    @filter = filter.presence_in(FILTERS)
    @sprint = project.sprints.upcoming.first
  end

  def planned_tasks = filtered(tasks.select { |task| task.sprint_id == sprint&.id && sprint })
  def backlog_tasks = filtered(tasks.select { |task| task.sprint_id.nil? })
  def all_count = tasks.count { |task| task.sprint_id.nil? || task.sprint_id == sprint&.id }

  def counts
    visible = tasks.select { |task| task.sprint_id.nil? || task.sprint_id == sprint&.id }
    { "all" => visible.size, "chains" => visible.count(&:chain_id), "unassigned" => visible.count { |t| t.assignee_id.nil? },
      "unestimated" => visible.count { |t| t.estimate_minutes.nil? } }
  end

  def planned_days = days(planned_tasks_unfiltered.sum { |task| task.estimate_minutes.to_i })
  def capacity_days = project.members.size * DAYS_PER_PERSON
  def free_days = [ capacity_days - planned_days, 0 ].max

  # [[user, planned_days]] for everyone on the project, busiest first.
  def load_by_person
    planned = planned_tasks_unfiltered.group_by(&:assignee_id).transform_values { |list| days(list.sum { |task| task.estimate_minutes.to_i }) }
    project.members.map { |user| [ user, planned.fetch(user.id, 0) ] }.sort_by { |user, load| [ -load, user.name ] }
  end

  def backlog_days = days(backlog_tasks.sum { |task| task.estimate_minutes.to_i })

  private

  def days(minutes) = (minutes / Task::MINUTES_PER_DAY.to_f).round

  def planned_tasks_unfiltered
    @planned_tasks_unfiltered ||= sprint ? tasks.select { |task| task.sprint_id == sprint.id } : []
  end

  def filtered(list)
    case filter
    when "chains" then list.select(&:chain_id)
    when "unassigned" then list.select { |task| task.assignee_id.nil? }
    when "unestimated" then list.select { |task| task.estimate_minutes.nil? }
    else list
    end
  end

  def tasks
    @tasks ||= project.tasks.unlocked.where(status: "todo").includes(:assignee, :topic, :pull_requests, chain: :tasks).order(:position, :number).to_a
  end
end
