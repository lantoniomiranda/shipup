# The tabs of a project's header (Topics, Backlog, Board…) and the order each person prefers.
module ProjectTabs
  TABS = [
    { key: "topics", label: "Topics", icon: "messages-square" },
    { key: "backlog", label: "Backlog", icon: "list-todo" },
    { key: "board", label: "Board", icon: "kanban" },
    { key: "timeline", label: "Timeline", icon: "calendar-range" },
    { key: "clients", label: "Clients", icon: "building-2" },
    { key: "people", label: "People", icon: "users" },
    { key: "analytics", label: "Analytics", icon: "chart-column" }
  ].freeze
  KEYS = TABS.map { |tab| tab[:key] }.freeze

  module_function

  # The tabs in the person's own order; tabs they haven't placed yet keep their default position
  # after the ones they have.
  def for(user)
    saved = user&.preference&.project_tab_order || []
    ordered = saved.filter_map { |key| TABS.find { |tab| tab[:key] == key } }
    ordered + (TABS - ordered)
  end
end
