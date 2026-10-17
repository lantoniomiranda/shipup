# Applies a GitHub `pull_request` webhook payload: upserts the PR and links it to every
# task whose key (e.g. APO-97) appears in its title, branch or description.
class Integrations::Github::PullRequestSync
  KEY_PATTERN = /\b([A-Z]{2,5})-(\d+)\b/

  def self.call(payload)
    new(payload).call
  end

  def initialize(payload)
    @payload = payload
    @pr = payload.fetch("pull_request")
  end

  # Returns the synced PullRequest records (one per linked project repository).
  def call
    GithubRepository.where(external_id: @payload.dig("repository", "id")).map do |repository|
      pull_request = upsert(repository)
      link_tasks(repository.project, pull_request)
      pull_request
    end
  end

  private

  def upsert(repository)
    repository.pull_requests.find_or_initialize_by(number: @pr.fetch("number")).tap do |pull_request|
      pull_request.update!(title: @pr.fetch("title"), url: @pr.fetch("html_url"), author_login: @pr.dig("user", "login"),
                           state: state, merged_at: @pr["merged_at"])
    end
  end

  def state
    return "merged" if @pr["merged"] || @pr["merged_at"]

    @pr.fetch("state") == "closed" ? "closed" : "open"
  end

  def link_tasks(project, pull_request)
    text = [ @pr["title"], @pr.dig("head", "ref"), @pr["body"] ].compact.join(" ")
    numbers = text.scan(KEY_PATTERN).select { |key, _| key == project.key }.map { |_, number| number.to_i }
    project.tasks.where(number: numbers).find_each do |task|
      TaskPullRequest.find_or_create_by!(task: task, pull_request: pull_request)
    end
  end
end
