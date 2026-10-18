# Demo data mirroring the ShipUp design (Orbit Labs). Safe to run repeatedly.
today = Date.current

roles = {} # user id => role on every demo project (Inês is also the dev superadmin, see config/environments/development.rb)
people = [
  [ "Inês Machado", "ines", "Europe/Lisbon", "teal", "admin" ],
  [ "Jonas Keller", "jonas", "Europe/Berlin", "mustard", "admin" ],
  [ "Sofia Reyes", "sofia", "America/Chicago", "plum", "member" ],
  [ "Daniel Okafor", "daniel", "Asia/Tokyo", "blue", "member" ],
  [ "Ananya Lal", "ananya", "Europe/Lisbon", "orange", "member" ],
  [ "Priya Varma", "priya", "Asia/Kolkata", "teal", "admin" ]
].to_h do |name, handle, zone, color, role|
  user = User.find_or_create_by!(email: "#{handle}@orbitlabs.dev") { |u| u.assign_attributes(name: name, time_zone: zone, avatar_color: color) }
  roles[user.id] = role
  [ handle, user ]
end

projects = [
  [ "Apollo Gateway", "APO", "orange", "rocket", "Public API gateway, auth and rate limiting for partner integrations.", 14, 3, 68 ],
  [ "Mobile Atlas", "ATL", "teal", "smartphone", "Offline-first iOS and Android app for field engineers.", 8, 6, 41 ],
  [ "Data Pipeline", "DAT", "plum", "workflow", "Streaming ingestion, dbt models and quality alerting.", 22, 1, 83 ],
  [ "Billing Core", "BIL", "blue", "receipt", "Invoicing, usage metering and regional tax rules.", 5, 9, 25 ],
  [ "Design System", "DSG", "mustard", "palette", "Tokens, components and docs shared across every product.", 3, 4, 57 ]
].each_with_index.map do |(name, key, color, icon, description, sprint, days_left, _progress), index|
  project = Project.find_or_create_by!(key: key) do |p|
    p.assign_attributes(name: name, color: color, icon: icon, description: description, position: index, last_activity_at: (index + 1).hours.ago)
  end
  project.sprints.find_or_create_by!(number: sprint) { |s| s.assign_attributes(starts_on: today + days_left - 14, ends_on: today + days_left - 1, state: "active") }
  people.each_value { |user| ProjectMembership.find_or_create_by!(project: project, user: user) { |membership| membership.role = roles.fetch(user.id) } }
  project
end

apollo = projects.first
sprint = apollo.active_sprint

%w[Backend Frontend Infra Docs].zip(%w[orange blue teal mustard]).each do |name, color|
  apollo.labels.find_or_create_by!(name: name) { |l| l.color = color }
end

northwind = Client.find_or_create_by!(name: "Northwind")
fabrikam = Client.find_or_create_by!(name: "Fabrikam")
northwind.contacts.find_or_create_by!(email: "priya@northwind.io") { |c| c.name = "Priya Nair" }
fabrikam.contacts.find_or_create_by!(email: "tom.weber@fabrikam.com") { |c| c.name = "Tom Weber" }
[ northwind, fabrikam ].each { |client| ProjectClient.find_or_create_by!(project: apollo, client: client) { |pc| pc.status = "active" } }

[
  [ "Rate limiting per API key", "feature", "Cap requests per key and return a clear error. Per-minute windows, with burst allowance.", "jonas", northwind, 27, 21.days, "open" ],
  [ "Sandbox environment per partner", "feature", "One isolated sandbox per partner, built with Terraform, with a daily quota of 1,000 requests.", "ines", fabrikam, 21, 5.days.ago, "open" ],
  [ "Refresh tokens expire silently after 24h", "issue", "Partners report 401s exactly 24h after authorizing. The refresh never rotates and the failure is silent.", "sofia", northwind, 18, 2.days.ago, "open" ],
  [ "Latency spike on /v2/orders in EU", "issue", "p95 jumped from 180ms to 900ms right after the Envoy canary. Cache order lookups at the EU edge.", "jonas", nil, 15, 1.week.ago, "open" ],
  [ "Webhook retries with exponential backoff", "feature", "Retry failed webhook deliveries with growing delays and a dead-letter view for the ones that never land.", "daniel", nil, 9, 3.days.ago, "open" ],
  [ "Dark mode for the partner dashboard", "feature", "Nice to have, but outside this quarter's scope. Revisit when the dashboard redesign lands.", "priya", nil, -3, 14.days.ago, "canceled" ]
].each do |title, kind, body, author, client, score, age, status|
  age = age.is_a?(Numeric) ? age.days.ago : age
  topic = apollo.topics.find_or_create_by!(title: title) do |t|
    t.assign_attributes(kind: kind, body: body, author: people.fetch(author), client: client, votes_score: score, status: status, created_at: age, last_activity_at: age)
  end
end

refresh_thread = [
  [ "jonas", "Reproduced on staging. TTL is hard-coded in auth/session.ts. Proposal: sliding window plus a token.expiring event." ],
  [ "ines", "Backend fix first, then a dashboard banner so partners see it coming. @Daniel can you size both?" ],
  [ "daniel", "Backend ~3d, banner ~1d. Happy to take both, backend before frontend." ]
]
refresh_topic = apollo.topics.find_by!(title: "Refresh tokens expire silently after 24h")
refresh_thread.each_with_index do |(author, body), index|
  refresh_topic.messages.find_or_create_by!(author: people.fetch(author), body: body) { |m| m.created_at = 2.days.ago + (index + 1).hours }
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

# A chain from the refresh-token topic: backend first, then dashboard, then QA.
unless apollo.chains.exists?(title: "Fix silent refresh-token expiry")
  Chain.create_with_steps!(project: apollo, creator: people.fetch("ines"), topic: refresh_topic, sprint: sprint, title: "Fix silent refresh-token expiry", steps: [
    { title: "Backend", description: "Per-key counters and limit middleware", assignee_id: people.fetch("jonas").id, estimate_days: 3 },
    { title: "Dashboard", description: "Usage dashboard and 429 banner", assignee_id: people.fetch("jonas").id, estimate_days: 2 },
    { title: "QA", description: "Soak test with partner keys", assignee_id: people.fetch("ananya").id, estimate_days: 1 }
  ])
end

# One connected GitHub repo with a pull request on the rate-limiting task.
github = IntegrationConnection.find_or_create_by!(provider: "github") { |c| c.assign_attributes(external_account: "orbitlabs", connected_by: people.fetch("ines")) }
repository = apollo.github_repositories.find_or_create_by!(external_id: 1001) { |r| r.assign_attributes(integration_connection: github, full_name: "orbitlabs/gateway") }
pull_request = repository.pull_requests.find_or_create_by!(number: 471) { |pr| pr.assign_attributes(title: "APO rate limiting", url: "https://github.com/orbitlabs/gateway/pull/471", state: "open") }
TaskPullRequest.find_or_create_by!(task: rate_limiting_task, pull_request: pull_request) if defined?(rate_limiting_task)

# Give every other project some finished work so its sprint shows XP progress.
{ "ATL" => 41, "DAT" => 83, "BIL" => 25, "DSG" => 57 }.each do |key, percent|
  project = projects.find { |p| p.key == key }
  [ [ "Shipped work", "done", percent ], [ "Remaining work", "todo", 100 - percent ] ].each do |title, status, minutes|
    project.tasks.find_or_create_by!(title: title) do |t|
      t.assign_attributes(status: status, creator: people.fetch("ines"), sprint: project.active_sprint, estimate_minutes: minutes)
    end
  end
end

# Inês has a timer running on the rate-limiting task, as in the design.
rate_limiting = apollo.tasks.find_by!(title: "Per-key rate limiting")
rate_limiting_task = rate_limiting
TaskPullRequest.find_or_create_by!(task: rate_limiting, pull_request: pull_request)
people.fetch("ines").time_entries.find_or_create_by!(ended_at: nil) { |entry| entry.assign_attributes(task: rate_limiting, started_at: 2.hours.ago - 14.minutes) }

TimeOffRequest::KINDS.zip([ 22, 5, 3 ]).each do |kind, days|
  TimeOffAllowance.find_or_create_by!(user: people.fetch("ines"), kind: kind, year: today.year) { |a| a.days = days }
end

# Team time off for the month view and the approval queue.
month = today.beginning_of_month
[
  [ "ananya", "vacation", 4, 8, "approved" ], [ "jonas", "sick", 11, 11, "approved" ], [ "daniel", "vacation", 18, 19, "approved" ],
  [ "sofia", "vacation", 25, 27, "pending" ], [ "ines", "vacation", 21, 29, "approved" ]
].each do |handle, kind, from, to, status|
  request = TimeOffRequest.find_or_initialize_by(user: people.fetch(handle), kind: kind, starts_on: month + from, ends_on: month + to)
  next if request.persisted?

  request.assign_attributes(status: status, approver: people.fetch("priya"))
  request.save!(validate: false)
end

# Next sprint plus a backlog for sprint planning.
next_sprint = apollo.sprints.find_or_create_by!(number: sprint.number + 1) { |s| s.assign_attributes(starts_on: sprint.ends_on + 1, ends_on: sprint.ends_on + 14) }
[
  [ "Webhook retries with backoff", next_sprint, "daniel", 5 ], [ "Add Retry-After header to 429s", next_sprint, "ananya", 2 ],
  [ "Partner status page copy review", next_sprint, "sofia", 1 ],
  [ "Audit log export", nil, nil, 8 ], [ "Sandbox usage dashboard", nil, "jonas", 4 ], [ "Rotate signing keys automatically", nil, "ines", nil ],
  [ "Rate-limit headers in OpenAPI spec", nil, "sofia", 1 ], [ "Partner webhook logs viewer", nil, nil, 6 ]
].each do |title, target, assignee, days|
  apollo.tasks.find_or_create_by!(title: title) do |t|
    t.assign_attributes(creator: people.fetch("ines"), sprint: target, assignee: assignee && people.fetch(assignee), estimate_days: days)
  end
end

# History so analytics and the timeline have something to show: past time entries and meetings.
if rate_limiting.time_entries.where.not(ended_at: nil).none?
  (1..6).each do |weeks_ago|
    started = weeks_ago.weeks.ago.beginning_of_week + 9.hours
    people.values_at("jonas", "daniel", "ananya").each_with_index do |user, index|
      rate_limiting.time_entries.create!(user: user, started_at: started + index.days, ended_at: started + index.days + (4 + weeks_ago).hours)
    end
  end
end

[ [ refresh_topic, 1.week.ago ], [ apollo.topics.find_by!(title: "Rate limiting per API key"), 3.days.from_now ] ].each do |topic, at|
  next if topic.meetings.exists?

  meeting = topic.meetings.create!(organizer: people.fetch("ines"), provider: "zoom", starts_at: at.change(hour: 14), duration_minutes: 30,
                                   join_url: "https://zoom.us/j/#{topic.id}0000")
  people.values_at("ines", "jonas", "sofia").each { |user| meeting.participants.create!(user: user) }
end

# Task chat with a quoted reply.
if rate_limiting.messages.none?
  first = rate_limiting.messages.create!(author: people.fetch("jonas"), body: "Counters are merged. Dashboard is next, then QA.", created_at: 5.hours.ago)
  rate_limiting.messages.create!(author: people.fetch("ines"), body: "Northwind needs this before their Oct 26 launch. QA starts when the dashboard lands.", parent: first, created_at: 4.hours.ago)
end
