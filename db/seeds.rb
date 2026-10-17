# Demo workspace mirroring the Nook design. Safe to run repeatedly.
today = Date.current

workspace = Workspace.find_or_create_by!(slug: "orbit-labs") do |w|
  w.name = "Orbit Labs"
  w.email_domain = "orbitlabs.dev"
end

people = [
  [ "Inês Machado", "ines", "Europe/Lisbon", "teal", "admin" ],
  [ "Jonas Keller", "jonas", "Europe/Berlin", "mustard", "manager" ],
  [ "Sofia Reyes", "sofia", "America/Chicago", "plum", "member" ],
  [ "Daniel Okafor", "daniel", "Asia/Tokyo", "blue", "member" ],
  [ "Ananya Lal", "ananya", "Europe/Lisbon", "orange", "member" ],
  [ "Priya Varma", "priya", "Asia/Kolkata", "teal", "manager" ]
].to_h do |name, handle, zone, color, role|
  user = User.find_or_create_by!(email: "#{handle}@orbitlabs.dev") { |u| u.assign_attributes(name: name, time_zone: zone, avatar_color: color) }
  Membership.find_or_create_by!(workspace: workspace, user: user) { |m| m.role = role }
  [ handle, user ]
end

projects = [
  [ "Apollo Gateway", "APO", "orange", "rocket", "Public API gateway, auth and rate limiting for partner integrations.", 14, 3, 68 ],
  [ "Mobile Atlas", "ATL", "teal", "smartphone", "Offline-first iOS and Android app for field engineers.", 8, 6, 41 ],
  [ "Data Pipeline", "DAT", "plum", "workflow", "Streaming ingestion, dbt models and quality alerting.", 22, 1, 83 ],
  [ "Billing Core", "BIL", "blue", "receipt", "Invoicing, usage metering and regional tax rules.", 5, 9, 25 ],
  [ "Design System", "DSG", "mustard", "palette", "Tokens, components and docs shared across every product.", 3, 4, 57 ]
].each_with_index.map do |(name, key, color, icon, description, sprint, days_left, _progress), index|
  project = Project.find_or_create_by!(workspace: workspace, key: key) do |p|
    p.assign_attributes(name: name, color: color, icon: icon, description: description, position: index, last_activity_at: (index + 1).hours.ago)
  end
  project.sprints.find_or_create_by!(number: sprint) { |s| s.assign_attributes(starts_on: today + days_left - 14, ends_on: today + days_left - 1) }
  people.each_value { |user| ProjectMembership.find_or_create_by!(project: project, user: user) }
  project
end

apollo = projects.first
sprint = apollo.current_sprint

%w[Backend Frontend Infra Docs].zip(%w[orange blue teal mustard]).each do |name, color|
  apollo.labels.find_or_create_by!(name: name) { |l| l.color = color }
end

northwind = workspace.clients.find_or_create_by!(name: "Northwind")
fabrikam = workspace.clients.find_or_create_by!(name: "Fabrikam")
northwind.contacts.find_or_create_by!(email: "priya@northwind.io") { |c| c.name = "Priya Nair" }
fabrikam.contacts.find_or_create_by!(email: "tom.weber@fabrikam.com") { |c| c.name = "Tom Weber" }
[ northwind, fabrikam ].each { |client| ProjectClient.find_or_create_by!(project: apollo, client: client) { |pc| pc.status = "active" } }

[
  [ "Rate limiting per API key", "feature", "Cap requests per key and return a clear error. Per-minute windows, with burst allowance.", "jonas", northwind, 27 ],
  [ "Sandbox environment per partner", "feature", "One isolated sandbox per partner, built with Terraform, with a daily quota of 1,000 requests.", "ines", fabrikam, 21 ],
  [ "Refresh tokens expire silently after 24h", "issue", "Partners report 401s exactly 24h after authorizing. The refresh never rotates and the failure is silent.", "sofia", northwind, 18 ],
  [ "Latency spike on /v2/orders in EU", "issue", "p95 jumped from 180ms to 900ms right after the Envoy canary. Cache order lookups at the EU edge.", "jonas", nil, 15 ],
  [ "Webhook retries with exponential backoff", "feature", "Retry failed webhook deliveries with growing delays and a dead-letter view for the ones that never land.", "daniel", nil, 9 ]
].each do |title, kind, body, author, client, score|
  topic = apollo.topics.find_or_create_by!(title: title) do |t|
    t.assign_attributes(kind: kind, body: body, author: people.fetch(author), client: client, votes_score: score, last_activity_at: Time.current)
  end
  topic.messages.find_or_create_by!(author: people.fetch(author), body: body)
end

[
  [ "Per-key rate limiting", "in_progress", "jonas", 600, "Backend" ],
  [ "Cache order lookups in EU edge", "testing", "ananya", 960, "Backend" ],
  [ "Partner sandbox environment", "ready_to_deploy", "daniel", 1920, "Infra" ],
  [ "OpenAPI spec published", "done", "sofia", 720, "Docs" ],
  [ "Fix silent refresh-token expiry", "todo", "daniel", 1920, "Backend" ]
].each do |title, status, assignee, minutes, label|
  task = apollo.tasks.find_or_create_by!(title: title) do |t|
    t.assign_attributes(status: status, assignee: people.fetch(assignee), creator: people.fetch("ines"), sprint: sprint, estimate_minutes: minutes, due_on: today + 5)
  end
  task.labels << apollo.labels.find_by!(name: label) unless task.labels.exists?
end

# Give every other project some finished work so its sprint shows XP progress.
{ "ATL" => 41, "DAT" => 83, "BIL" => 25, "DSG" => 57 }.each do |key, percent|
  project = projects.find { |p| p.key == key }
  [ [ "Shipped work", "done", percent ], [ "Remaining work", "todo", 100 - percent ] ].each do |title, status, minutes|
    project.tasks.find_or_create_by!(title: title) do |t|
      t.assign_attributes(status: status, creator: people.fetch("ines"), sprint: project.current_sprint, estimate_minutes: minutes)
    end
  end
end

# Inês has a timer running on the rate-limiting task, as in the design.
rate_limiting = apollo.tasks.find_by!(title: "Per-key rate limiting")
people.fetch("ines").time_entries.find_or_create_by!(ended_at: nil) { |entry| entry.assign_attributes(task: rate_limiting, started_at: 2.hours.ago - 14.minutes) }

TimeOffRequest::KINDS.zip([ 22, 5, 3 ]).each do |kind, days|
  TimeOffAllowance.find_or_create_by!(user: people.fetch("ines"), kind: kind, year: today.year) { |a| a.days = days }
end
