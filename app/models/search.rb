# Quick search across the topics, tasks and projects the user can see (the "Super Space" palette).
class Search
  SCOPES = %w[everything topics tasks projects].freeze
  LIMIT = 6
  Results = Data.define(:topics, :tasks, :projects) do
    def counts = { "topics" => topics.size, "tasks" => tasks.size, "projects" => projects.size }
    def empty? = counts.values.all?(&:zero?)
  end

  attr_reader :query, :scope

  def initialize(user:, query:, scope: nil)
    @user = user
    @query = query.to_s.strip
    @scope = scope.presence_in(SCOPES) || "everything"
  end

  def results
    @results ||= if query.length < 2
      Results.new(topics: [], tasks: [], projects: [])
    else
      Results.new(topics: include?("topics") ? topics : [], tasks: include?("tasks") ? tasks : [], projects: include?("projects") ? projects : [])
    end
  end

  private

  def include?(name) = scope == "everything" || scope == name
  def pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
  def project_ids = @project_ids ||= Project.visible_to(@user).ids

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
    Project.visible_to(@user).where("name ILIKE :q OR key ILIKE :q", q: pattern).limit(LIMIT)
  end
end
