# Turns a Notification into a sentence and a link, whatever kind of record it points at.
module NotificationsHelper
  ICONS = { "mention_or_reply" => "corner-down-right", "new_topic" => "messages-square", "similar_topic" => "sparkles",
            "task_assigned" => "circle-check", "subtask_unlocked" => "lock", "meeting_invite" => "video" }.freeze

  def notification_icon(notification) = ICONS.fetch(notification.kind)

  def notification_summary(notification)
    actor = notification.actor&.short_name || "Someone"
    subject = notification.subject

    case notification.kind
    when "mention_or_reply"
      replied = subject.parent&.author_id == notification.user_id
      "#{actor} #{replied ? "replied to you" : "mentioned you"} in “#{subject.thread.title}”"
    when "task_assigned" then "#{actor} assigned you #{subject.key} · #{subject.title}"
    when "subtask_unlocked" then "#{subject.key} · #{subject.title} is unlocked for you"
    when "new_topic" then "#{actor} opened “#{subject.title}”"
    when "meeting_invite" then "#{actor} invited you to discuss “#{subject.topic.title}”"
    else "#{actor} did something"
    end
  end

  # Where clicking a notification should take you; nil when the record is gone.
  def notification_target(notification)
    subject = notification.subject
    return unless subject

    case subject
    when TopicMessage then project_topic_path(subject.topic.project, subject.topic, anchor: "message-#{subject.id}")
    when TaskMessage then project_task_path(subject.task.project, subject.task, anchor: "message-#{subject.id}")
    when Task then project_task_path(subject.project, subject)
    when Topic then project_topic_path(subject.project, subject)
    when Meeting then project_topic_path(subject.topic.project, subject.topic)
    end
  end
end
