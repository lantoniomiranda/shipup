# Per-request state, reset automatically by Rails between requests.
class Current < ActiveSupport::CurrentAttributes
  attribute :session, :workspace
  delegate :user, to: :session, allow_nil: true
end
