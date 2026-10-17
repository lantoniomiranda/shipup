# The sprint board: tasks grouped into status columns, plus sprint XP.
# "XP" is estimated hours: done / total for the sprint.
class Board
  LABELS = { "todo" => "To Do", "in_progress" => "In Progress", "testing" => "Testing", "ready_to_deploy" => "Ready to deploy", "done" => "Done" }.freeze
  PIPS = { "todo" => "ink", "in_progress" => "orange", "testing" => "mustard", "ready_to_deploy" => "blue", "done" => "teal" }.freeze
  Column = Data.define(:status, :label, :pip, :tasks)

  attr_reader :project, :sprint

  def initialize(project:, sprint: project.active_sprint)
    @project = project
    @sprint = sprint
  end

  def columns
    @columns ||= Task::STATUSES.map do |status|
      Column.new(status: status, label: LABELS.fetch(status), pip: PIPS.fetch(status), tasks: tasks_by_status.fetch(status, []))
    end
  end

  def total_points
    hours(all_tasks.sum { |task| task.estimate_minutes.to_i })
  end

  def done_points
    hours(all_tasks.select(&:done?).sum { |task| task.estimate_minutes.to_i })
  end

  def progress_percent
    total_points.zero? ? 0 : (done_points * 100.0 / total_points).round
  end

  private

  def hours(minutes)
    (minutes / 60.0).round
  end

  def all_tasks
    @all_tasks ||= scope.to_a
  end

  def tasks_by_status
    @tasks_by_status ||= all_tasks.group_by(&:status)
  end

  def scope
    base = project.tasks.unlocked.with_logged_minutes
                  .includes(:assignee, :labels, :topic, :pull_requests, chain: :tasks)
                  .order(:position, :number)
    sprint ? base.where(sprint: sprint) : base.none
  end
end
