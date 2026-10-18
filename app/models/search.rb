# Quick search across pages, topics, tasks, chains and projects (the "Super Space" palette). It is always
# global; opened from inside a project it also knows that project, whose own topics, tasks and chains
# come first (see Results#in_project / #elsewhere).
class Search
  SCOPES = %w[everything pages topics tasks chains projects].freeze
  LIMIT = 6
  PAGE_LIMIT = 8
  Results = Data.define(:pages, :topics, :tasks, :chains, :projects, :project) do
    def counts = { "pages" => pages.size, "topics" => topics.size, "tasks" => tasks.size, "chains" => chains.size, "projects" => projects.size }
    def empty? = counts.values.all?(&:zero?)

    # Topics, tasks and chains of the project the search was opened from, and of everywhere else.
    def in_project(records) = project ? records.select { |record| record.project_id == project.id } : []
    def elsewhere(records) = project ? records.reject { |record| record.project_id == project.id } : records
  end

  attr_reader :query, :scope, :project

  def initialize(user:, query:, scope: nil, project: nil)
    @user = user
    @project = project
    @query = query.to_s.strip
    @scope = scope.presence_in(SCOPES) || "everything"
  end

  def results
    @results ||= Results.new(
      pages: include?("pages") ? pages : [],
      topics: searchable? && include?("topics") ? topics : [],
      tasks: searchable? && include?("tasks") ? tasks : [],
      chains: searchable? && include?("chains") ? chains : [],
      projects: searchable? && include?("projects") ? projects : [],
      project: project
    )
  end

  # Pages answer from the first keystroke; the rest needs two letters.
  def searchable? = query.length >= 2

  private

  def pages = Search::Pages.new(user: @user, project: project).matching(query, limit: PAGE_LIMIT)
  def include?(name) = scope == "everything" || scope == name
  def pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
  def project_ids = @project_ids ||= Project.visible_to(@user).ids

  # The current project's rows sort first, so they survive the limit.
  def project_first(table)
    return Arel.sql("1") unless project

    Arel.sql(ActiveRecord::Base.sanitize_sql_array([ "(#{table}.project_id = ?) DESC", project.id ]))
  end

  def topics
    Topic.where(project_id: project_ids).where("topics.title ILIKE :q OR topics.body ILIKE :q", q: pattern)
         .includes(:project, :author, tasks: :project).order(project_first("topics"), votes_score: :desc).limit(LIMIT)
  end

  def chains
    Chain.where(project_id: project_ids).where("chains.title ILIKE ?", pattern)
         .includes(:project, :tasks).order(project_first("chains"), :title).limit(LIMIT)
  end

  def tasks
    key_match = query.match(/\A([A-Za-z]{2,5})-(\d+)\z/)
    scope = Task.where(project_id: project_ids).includes(:project, :chain)
    scope = key_match ? scope.joins(:project).where(projects: { key: key_match[1].upcase }, number: key_match[2]) : scope.where("tasks.title ILIKE ?", pattern)
    scope.order(project_first("tasks"), :number).limit(LIMIT)
  end

  def projects
    Project.visible_to(@user).where("name ILIKE :q OR key ILIKE :q", q: pattern).limit(LIMIT)
  end
end
