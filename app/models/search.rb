# Workspace-wide quick search across pages, topics, tasks and projects (the "Super Space" palette).
class Search
  SCOPES = %w[everything pages topics tasks projects].freeze
  LIMIT = 6
  PAGE_LIMIT = 8
  Results = Data.define(:pages, :topics, :tasks, :projects) do
    def counts = { "pages" => pages.size, "topics" => topics.size, "tasks" => tasks.size, "projects" => projects.size }
    def empty? = counts.values.all?(&:zero?)
  end

  attr_reader :query, :scope

  def initialize(workspace:, query:, scope: nil, user: Current.user)
    @workspace = workspace
    @user = user
    @query = query.to_s.strip
    @scope = scope.presence_in(SCOPES) || "everything"
  end

  def results
    @results ||= Results.new(
      pages: include?("pages") ? pages : [],
      topics: searchable? && include?("topics") ? topics : [],
      tasks: searchable? && include?("tasks") ? tasks : [],
      projects: searchable? && include?("projects") ? projects : []
    )
  end

  # Pages answer from the first keystroke; the rest needs two letters.
  def searchable? = query.length >= 2

  private

  def pages = Search::Pages.new(user: @user, workspace: @workspace).matching(query, limit: PAGE_LIMIT)
  def include?(name) = scope == "everything" || scope == name
  def pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
  def project_ids = @project_ids ||= @workspace.projects.ids

  def topics
    Topic.where(project_id: project_ids).where("topics.title ILIKE :q OR topics.body ILIKE :q", q: pattern)
         .includes(:project, :author, tasks: :project).order(votes_score: :desc).limit(LIMIT)
  end

  def tasks
    key_match = query.match(/\A([A-Za-z]{2,5})-(\d+)\z/)
    scope = Task.where(project_id: project_ids).includes(:project, :chain)
    scope = key_match ? scope.joins(:project).where(projects: { key: key_match[1].upcase }, number: key_match[2]) : scope.where("tasks.title ILIKE ?", pattern)
    scope.order(:number).limit(LIMIT)
  end

  def projects
    @workspace.projects.where("name ILIKE :q OR key ILIKE :q", q: pattern).limit(LIMIT)
  end
end
