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
