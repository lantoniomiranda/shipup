module ApplicationHelper
  # Sets the breadcrumb trail shown in the top bar; the last crumb is the current page.
  def breadcrumbs(*crumbs)
    content_for(:breadcrumbs) { safe_join(crumbs.each_with_index.map { |crumb, index| breadcrumb(crumb, last: index == crumbs.size - 1) }, icon("chevron-right")) }
  end

  # <span class="avatar avatar--md avatar--teal">IM</span>
  def avatar(user, size: :md, **options)
    tag.span(user.initials, class: [ "avatar", "avatar--#{size}", "avatar--#{user.avatar_color}", options.delete(:class) ].compact,
                            title: user.name, **options)
  end

  # Sun / sunrise / moon for a time zone's current local hour.
  def daypart_icon(zone, now: Time.current)
    case now.in_time_zone(zone).hour
    when 7..8, 18..19 then "sunrise"
    when 9..17 then "sun"
    else "moon"
    end
  end

  def local_time(zone, now: Time.current)
    now.in_time_zone(zone).strftime("%H:%M")
  end

  # "Active 12 min ago", "Active 3h ago", "Active yesterday", "Active 4d ago"
  def time_ago_label(time, now: Time.current)
    return "No activity yet" unless time

    minutes = ((now - time) / 60).floor
    "Active " + case minutes
    when ...1 then "just now"
    when 1...60 then "#{minutes} min ago"
    when 60...1440 then "#{minutes / 60}h ago"
    when 1440...2880 then "yesterday"
    else "#{minutes / 1440}d ago"
    end
  end

  PROJECT_TABS = [
    { key: :topics, label: "Topics", icon: "messages-square", hotkey: "g d" },
    { key: :backlog, label: "Backlog", icon: "list-todo", hotkey: "g l" },
    { key: :board, label: "Board", icon: "kanban", hotkey: "g b" },
    { key: :timeline, label: "Timeline", icon: "calendar-range", hotkey: "g t" },
    { key: :clients, label: "Clients", icon: "building-2", hotkey: "g c" },
    { key: :analytics, label: "Analytics", icon: "chart-column", hotkey: "g a" }
  ].freeze

  # Renders the project header (name, sprint, tabs, members) above the content frame.
  def project_header(project, active:)
    breadcrumbs [ "Projects", root_path ], project.name
    content_for(:content_class, "shell__content--bare")
    content_for(:project_header) { render("projects/header", project: project, active: active) }
  end

  # Where a project tab goes; tabs for screens that are not built yet return nil.
  def project_tab_path(project, tab)
    case tab
    when :topics then project_topics_path(project)
    end
  end

  # "2 days ago" inside the first week, then a plain "12 Sep".
  def topic_age(time, now: Time.current)
    days = (now.to_date - time.to_date).to_i
    return "today" if days.zero?
    return "#{days} #{"day".pluralize(days)} ago" if days < 7

    time.strftime("%-d %b")
  end

  # "08:12 · Austin": the moment in the author's own time zone.
  def author_time(time, user)
    "#{time.in_time_zone(user.time_zone).strftime("%H:%M")} · #{user.city}"
  end

  # Home filter links keep the default (active) URL clean.
  def projects_path_for(status)
    status == "active" ? root_path : root_path(status: status)
  end

  private

  def breadcrumb(crumb, last:)
    label, path = Array(crumb)
    css = last ? "crumb crumb--current" : "crumb"
    path ? link_to(label, path, class: css) : tag.span(label, class: css)
  end
end
