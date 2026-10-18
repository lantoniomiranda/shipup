# The "Pages" group of the quick-search palette: places in the app (Account, Connectors, a project's
# Board…) you can jump to by typing a few letters of their name.
class Search::Pages
  Page = Data.define(:title, :hint, :icon, :path)

  include Rails.application.routes.url_helpers

  def initialize(user:)
    @user = user
  end

  # Pages whose title or keywords contain every word of the query; everything for a blank query.
  def matching(query, limit:)
    words = query.to_s.downcase.split
    (general + project_areas).select { |entry| words.all? { |word| entry.last.include?(word) } }.map(&:first).first(limit)
  end

  private

  def admin? = @user.superadmin?

  # [Page, searchable text] pairs.
  def general
    [
      entry("Projects", "All your projects", "layers", root_path, "home dashboard"),
      entry("Account", "Profile, name and time zone", "user", account_path, "profile settings timezone zone"),
      entry("Appearance", "Theme, colours, font and density", "palette", appearance_path, "theme dark mode colour font zoom settings"),
      entry("Keyboard shortcuts", "See and remap shortcuts", "keyboard", keyboard_settings_path, "keybindings hotkeys settings"),
      entry("Notifications", "Mentions, replies and assignments", "bell", notifications_path, "inbox unread"),
      entry("Time off", "Requests, approvals and balance", "calendar", time_off_requests_path, "vacation leave holiday absence"),
      (entry("Connectors", "Zoom, Google Meet, GitHub and AI", "plug", integrations_path, "integrations connect zoom meet github llm ai meetings") if admin?)
    ].compact
  end

  def project_areas
    Project.visible_to(@user).order(:name).flat_map do |project|
      ProjectTabs.for(@user).filter_map do |tab|
        path = project_tab_path(project, tab[:key])
        entry("#{project.name} · #{tab[:label]}", "Project #{project.key}", tab[:icon], path, "#{project.key} #{tab[:key]}") if path
      end
    end
  end

  def entry(title, hint, icon, path, keywords = "")
    [ Page.new(title: title, hint: hint, icon: icon, path: path), "#{title} #{keywords}".downcase ]
  end

  def project_tab_path(project, tab)
    case tab.to_sym
    when :topics then project_topics_path(project)
    when :board then project_board_path(project)
    when :backlog then project_backlog_path(project)
    when :timeline then project_timeline_path(project)
    when :analytics then project_analytics_path(project)
    when :clients then project_clients_path(project)
    end
  end
end
