# iCalendar (.ics) feed of a user's due tasks and the project's meetings, for "Add to my calendar".
class CalendarExport
  def initialize(project, user)
    @project = project
    @user = user
  end

  def to_ics
    lines = [ "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//ohship//#{@project.key}//EN", "CALSCALE:GREGORIAN" ]
    due_tasks.each { |task| lines.concat(task_event(task)) }
    meetings.each { |meeting| lines.concat(meeting_event(meeting)) }
    lines << "END:VCALENDAR"
    lines.join("\r\n") + "\r\n"
  end

  private

  def due_tasks
    @project.tasks.where(assignee: @user).where.not(status: "done").where.not(due_on: nil).order(:due_on)
  end

  def meetings
    Meeting.where(topic: @project.topics).where("starts_at >= ?", 1.week.ago).includes(:topic).order(:starts_at)
  end

  def task_event(task)
    [ "BEGIN:VEVENT", "UID:task-#{task.id}@shipup", "DTSTAMP:#{stamp(Time.current)}", "DTSTART;VALUE=DATE:#{task.due_on.strftime("%Y%m%d")}",
      "SUMMARY:#{escape("Due: #{task.key} #{task.title}")}", "END:VEVENT" ]
  end

  def meeting_event(meeting)
    event = [ "BEGIN:VEVENT", "UID:meeting-#{meeting.id}@shipup", "DTSTAMP:#{stamp(Time.current)}", "DTSTART:#{stamp(meeting.starts_at)}", "DTEND:#{stamp(meeting.ends_at)}",
              "SUMMARY:#{escape(meeting.topic.title)}" ]
    event << "URL:#{meeting.join_url}" if meeting.join_url.present?
    event << "END:VEVENT"
  end

  def stamp(time) = time.utc.strftime("%Y%m%dT%H%M%SZ")

  def escape(text) = text.to_s.gsub(/[\;,]/) { |char| "\\#{char}" }.gsub("\n", "\\n")
end
