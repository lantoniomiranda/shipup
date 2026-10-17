# Thin GitHub REST client bound to a workspace's connection.
class Integrations::Github::Client
  API = "https://api.github.com".freeze

  def initialize(connection)
    @connection = connection
  end

  # Repositories the connected account can push to, newest activity first.
  def repositories
    get("/user/repos", per_page: 100, sort: "pushed", affiliation: "owner,collaborator,organization_member")
      .map { |repo| { external_id: repo["id"], full_name: repo["full_name"] } }
  end

  # Subscribes the repo to pull-request events delivered to our webhook endpoint.
  def create_webhook(full_name, url:, secret:)
    post("/repos/#{full_name}/hooks", name: "web", active: true, events: %w[pull_request],
         config: { url: url, content_type: "json", secret: secret })
  end

  private

  def get(path, params = {})
    request { |http| http.get("#{API}#{path}", params) }
  end

  def post(path, payload)
    request { |http| http.post("#{API}#{path}", payload.to_json, "Content-Type" => "application/json") }
  end

  def request
    http = Faraday.new do |faraday|
      faraday.headers["Authorization"] = "Bearer #{@connection.access_token}"
      faraday.headers["Accept"] = "application/vnd.github+json"
      faraday.response :json, content_type: /json/
    end
    response = yield http
    raise Integrations::Error, "GitHub request failed (#{response.status})" unless response.success?

    response.body
  end
end
