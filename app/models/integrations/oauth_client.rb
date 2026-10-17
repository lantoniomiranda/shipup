# Generic OAuth2 authorization-code flow (authorize URL, code exchange, token refresh).
class Integrations::OauthClient
  TokenSet = Data.define(:access_token, :refresh_token, :expires_at, :scopes)

  def initialize(provider, redirect_uri:)
    @provider = provider
    @redirect_uri = redirect_uri
  end

  def authorize_url(state:)
    query = { client_id: @provider.client_id, redirect_uri: @redirect_uri, response_type: "code",
              scope: @provider.scopes.join(" "), state: state }.merge(@provider.extra_authorize_params)
    "#{@provider.authorize_url}?#{query.to_query}"
  end

  def exchange(code:)
    request_token(grant_type: "authorization_code", code: code, redirect_uri: @redirect_uri)
  end

  # Providers like GitHub never return a new refresh token; keep the old one in that case.
  def refresh(refresh_token:)
    request_token(grant_type: "refresh_token", refresh_token: refresh_token).then do |tokens|
      tokens.refresh_token ? tokens : tokens.with(refresh_token: refresh_token)
    end
  end

  private

  def request_token(params)
    response = connection.post(@provider.token_url) do |request|
      request.headers["Accept"] = "application/json"
      if @provider.client_auth == :basic
        request.headers["Authorization"] = "Basic #{Base64.strict_encode64("#{@provider.client_id}:#{@provider.client_secret}")}"
      else
        params = params.merge(client_id: @provider.client_id, client_secret: @provider.client_secret)
      end
      request.body = params
    end

    body = response.body
    raise Integrations::Error, "#{@provider.label} token request failed: #{body['error_description'] || body['error'] || response.status}" if !response.success? || body["error"]

    TokenSet.new(
      access_token: body.fetch("access_token"), refresh_token: body["refresh_token"],
      expires_at: body["expires_in"] && Time.current + body["expires_in"].to_i.seconds, scopes: body["scope"]
    )
  end

  def connection
    Faraday.new do |faraday|
      faraday.request :url_encoded
      faraday.response :json, content_type: /json/
    end
  end
end
