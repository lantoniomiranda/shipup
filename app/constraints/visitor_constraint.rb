# Routing constraint: true for people who are not signed in, so "/" can show the public
# landing page to them and the dashboard to everyone else.
class VisitorConstraint
  def self.matches?(request)
    session_id = request.cookie_jar.signed[:session_id]
    session_id.blank? || !Session.exists?(id: session_id)
  end
end
