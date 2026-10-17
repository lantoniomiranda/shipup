module ApplicationHelper
  # The signed-in user's chosen palette; visitors get the defaults.
  def current_theme
    preference = Current.user&.preference
    { bg: preference&.theme_bg || "paper", accent: preference&.theme_accent || "orange" }
  end

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
    { key: :topics, label: "Topics", icon: "messages-square" },
    { key: :backlog, label: "Backlog", icon: "list-todo" },
    { key: :board, label: "Board", icon: "kanban" },
    { key: :timeline, label: "Timeline", icon: "calendar-range" },
    { key: :clients, label: "Clients", icon: "building-2" },
    { key: :analytics, label: "Analytics", icon: "chart-column" }
  ].freeze

  # `data: { hotkey: ... }` for a registered shortcut, e.g. link_to ..., data: hotkey_data(:board).
  def hotkey_data(id, **extra)
    { hotkey: Keybindings.keys(id) }.merge(extra)
  end

  # The little key cap for a registered shortcut.
  def key_hint(id)
    render "shared/key", label: Keybindings.label(id)
  end

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
    when :board then project_board_path(project)
    when :backlog then project_backlog_path(project)
    when :timeline then project_timeline_path(project)
    when :analytics then project_analytics_path(project)
    when :clients then project_clients_path(project)
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

  # A user's working hours on a 24h UTC axis, as [left%, width%] segments (two when they wrap midnight).
  def working_hour_segments(user)
    pref = user.preference
    offset = ActiveSupport::TimeZone[user.time_zone].now.utc_offset / 60
    start = (pref.work_day_start.hour * 60 + pref.work_day_start.min - offset) % 1440
    length = (pref.work_day_end.hour * 60 + pref.work_day_end.min) - (pref.work_day_start.hour * 60 + pref.work_day_start.min)
    spans = start + length <= 1440 ? [ [ start, length ] ] : [ [ start, 1440 - start ], [ 0, start + length - 1440 ] ]
    spans.map { |from, span| [ (from * 100.0 / 1440).round(2), (span * 100.0 / 1440).round(2) ] }
  end

  # Pastel tile colour for a client's initials, stable per client.
  def client_hue(client)
    Hued::HUES[client.id % Hued::HUES.size]
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
