# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_18_110001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "chains", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "topic_id"
    t.bigint "sprint_id"
    t.string "title", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_chains_on_project_id"
    t.index ["sprint_id"], name: "index_chains_on_sprint_id"
    t.index ["topic_id"], name: "index_chains_on_topic_id"
  end

  create_table "client_contacts", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "name", null: false
    t.citext "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "email"], name: "index_client_contacts_on_client_id_and_email", unique: true
    t.index ["client_id"], name: "index_client_contacts_on_client_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
    t.index ["name"], name: "index_clients_on_name", unique: true
  end

  create_table "github_repositories", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "integration_connection_id", null: false
    t.bigint "external_id", null: false
    t.string "full_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_github_repositories_on_external_id"
    t.index ["integration_connection_id"], name: "index_github_repositories_on_integration_connection_id"
    t.index ["project_id", "external_id"], name: "index_github_repositories_on_project_id_and_external_id", unique: true
    t.index ["project_id"], name: "index_github_repositories_on_project_id"
  end

  create_table "identities", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.citext "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "integration_connections", force: :cascade do |t|
    t.bigint "connected_by_id", null: false
    t.string "provider", null: false
    t.string "external_account", null: false
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "expires_at"
    t.string "scopes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["connected_by_id"], name: "index_integration_connections_on_connected_by_id"
    t.index ["provider"], name: "index_integration_connections_on_provider", unique: true
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "invited_by_id"
    t.citext "email", null: false
    t.string "role", default: "member", null: false
    t.string "token", null: false
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_invitations_on_email"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["project_id", "email"], name: "index_invitations_one_pending_per_email", unique: true, where: "((accepted_at IS NULL) AND (revoked_at IS NULL))"
    t.index ["project_id"], name: "index_invitations_on_project_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "labels", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.string "color", default: "orange", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "name"], name: "index_labels_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_labels_on_project_id"
  end

  create_table "meeting_digests", force: :cascade do |t|
    t.bigint "meeting_id", null: false
    t.text "summary"
    t.text "transcript"
    t.string "recording_url"
    t.integer "recording_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_id"], name: "index_meeting_digests_on_meeting_id", unique: true
  end

  create_table "meeting_participants", force: :cascade do |t|
    t.bigint "meeting_id", null: false
    t.bigint "user_id", null: false
    t.string "requirement", default: "required", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_id", "user_id"], name: "index_meeting_participants_on_meeting_id_and_user_id", unique: true
    t.index ["meeting_id"], name: "index_meeting_participants_on_meeting_id"
    t.index ["user_id"], name: "index_meeting_participants_on_user_id"
  end

  create_table "meetings", force: :cascade do |t|
    t.bigint "topic_id", null: false
    t.bigint "organizer_id", null: false
    t.string "provider", null: false
    t.string "external_id"
    t.string "join_url"
    t.datetime "starts_at", null: false
    t.integer "duration_minutes", default: 30, null: false
    t.boolean "transcribe", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organizer_id"], name: "index_meetings_on_organizer_id"
    t.index ["provider", "external_id"], name: "index_meetings_on_provider_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["topic_id", "starts_at"], name: "index_meetings_on_topic_id_and_starts_at"
    t.index ["topic_id"], name: "index_meetings_on_topic_id"
  end

  create_table "notification_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "kind", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "kind"], name: "index_notification_subscriptions_on_user_id_and_kind", unique: true
    t.index ["user_id"], name: "index_notification_subscriptions_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "actor_id"
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.string "kind", null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["subject_type", "subject_id"], name: "index_notifications_on_subject"
    t.index ["user_id", "read_at", "created_at"], name: "index_notifications_on_user_id_and_read_at_and_created_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "project_clients", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "client_id", null: false
    t.string "status", default: "invite_pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_project_clients_on_client_id"
    t.index ["project_id", "client_id"], name: "index_project_clients_on_project_id_and_client_id", unique: true
    t.index ["project_id"], name: "index_project_clients_on_project_id"
  end

  create_table "project_memberships", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "user_id"], name: "index_project_memberships_on_project_id_and_user_id", unique: true
    t.index ["project_id"], name: "index_project_memberships_on_project_id"
    t.index ["user_id"], name: "index_project_memberships_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "key", null: false
    t.text "description"
    t.string "color", default: "orange", null: false
    t.string "icon", default: "rocket", null: false
    t.string "status", default: "active", null: false
    t.integer "position", default: 0, null: false
    t.integer "last_task_number", default: 0, null: false
    t.datetime "last_activity_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_projects_on_key", unique: true
    t.index ["status", "position"], name: "index_projects_on_status_and_position"
  end

  create_table "pull_requests", force: :cascade do |t|
    t.bigint "github_repository_id", null: false
    t.integer "number", null: false
    t.string "title", null: false
    t.string "state", default: "open", null: false
    t.string "url", null: false
    t.string "author_login"
    t.datetime "merged_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_repository_id", "number"], name: "index_pull_requests_on_github_repository_id_and_number", unique: true
    t.index ["github_repository_id"], name: "index_pull_requests_on_github_repository_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "meeting_provider"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sprints", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.integer "number", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "state", default: "planned", null: false
    t.text "goal"
    t.datetime "completed_at"
    t.index ["project_id", "number"], name: "index_sprints_on_project_id_and_number", unique: true
    t.index ["project_id"], name: "index_sprints_on_project_id"
    t.index ["project_id"], name: "index_sprints_one_active_per_project", unique: true, where: "((state)::text = 'active'::text)"
  end

  create_table "task_labels", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "label_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["label_id"], name: "index_task_labels_on_label_id"
    t.index ["task_id", "label_id"], name: "index_task_labels_on_task_id_and_label_id", unique: true
    t.index ["task_id"], name: "index_task_labels_on_task_id"
  end

  create_table "task_messages", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "author_id", null: false
    t.bigint "parent_id"
    t.text "body", default: "", null: false
    t.datetime "edited_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_task_messages_on_author_id"
    t.index ["parent_id"], name: "index_task_messages_on_parent_id"
    t.index ["task_id", "created_at"], name: "index_task_messages_on_task_id_and_created_at"
    t.index ["task_id"], name: "index_task_messages_on_task_id"
  end

  create_table "task_pull_requests", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "pull_request_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pull_request_id"], name: "index_task_pull_requests_on_pull_request_id"
    t.index ["task_id", "pull_request_id"], name: "index_task_pull_requests_on_task_id_and_pull_request_id", unique: true
    t.index ["task_id"], name: "index_task_pull_requests_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "sprint_id"
    t.bigint "topic_id"
    t.bigint "chain_id"
    t.bigint "assignee_id"
    t.bigint "creator_id", null: false
    t.bigint "client_id"
    t.integer "number", null: false
    t.integer "chain_position"
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "todo", null: false
    t.integer "estimate_minutes"
    t.date "due_on"
    t.boolean "bug", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["chain_id", "chain_position"], name: "index_tasks_on_chain_id_and_chain_position", unique: true, where: "(chain_id IS NOT NULL)"
    t.index ["chain_id"], name: "index_tasks_on_chain_id"
    t.index ["client_id"], name: "index_tasks_on_client_id"
    t.index ["creator_id"], name: "index_tasks_on_creator_id"
    t.index ["project_id", "number"], name: "index_tasks_on_project_id_and_number", unique: true
    t.index ["project_id", "sprint_id", "status", "position"], name: "idx_on_project_id_sprint_id_status_position_b9e797924d"
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["sprint_id"], name: "index_tasks_on_sprint_id"
    t.index ["topic_id"], name: "index_tasks_on_topic_id"
  end

  create_table "time_entries", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "user_id", null: false
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_time_entries_on_task_id"
    t.index ["user_id", "started_at"], name: "index_time_entries_on_user_id_and_started_at"
    t.index ["user_id"], name: "index_time_entries_on_user_id"
    t.index ["user_id"], name: "index_time_entries_one_running_per_user", unique: true, where: "(ended_at IS NULL)"
  end

  create_table "time_off_allowances", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "kind", null: false
    t.integer "year", null: false
    t.integer "days", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "kind", "year"], name: "index_time_off_allowances_on_user_id_and_kind_and_year", unique: true
    t.index ["user_id"], name: "index_time_off_allowances_on_user_id"
  end

  create_table "time_off_requests", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "approver_id"
    t.string "kind", null: false
    t.string "status", default: "pending", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.integer "working_days", null: false
    t.datetime "decided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approver_id"], name: "index_time_off_requests_on_approver_id"
    t.index ["status", "starts_on"], name: "index_time_off_requests_on_status_and_starts_on"
    t.index ["user_id", "starts_on"], name: "index_time_off_requests_on_user_id_and_starts_on"
    t.index ["user_id"], name: "index_time_off_requests_on_user_id"
  end

  create_table "topic_messages", force: :cascade do |t|
    t.bigint "topic_id", null: false
    t.bigint "author_id", null: false
    t.text "body", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_id"
    t.datetime "edited_at"
    t.datetime "deleted_at"
    t.index ["author_id"], name: "index_topic_messages_on_author_id"
    t.index ["parent_id"], name: "index_topic_messages_on_parent_id"
    t.index ["topic_id", "created_at"], name: "index_topic_messages_on_topic_id_and_created_at"
    t.index ["topic_id"], name: "index_topic_messages_on_topic_id"
  end

  create_table "topic_votes", force: :cascade do |t|
    t.bigint "topic_id", null: false
    t.bigint "user_id", null: false
    t.integer "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["topic_id", "user_id"], name: "index_topic_votes_on_topic_id_and_user_id", unique: true
    t.index ["topic_id"], name: "index_topic_votes_on_topic_id"
    t.index ["user_id"], name: "index_topic_votes_on_user_id"
  end

  create_table "topics", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "author_id", null: false
    t.bigint "client_id"
    t.string "kind", default: "feature", null: false
    t.string "status", default: "open", null: false
    t.string "title", null: false
    t.text "body", default: "", null: false
    t.integer "votes_score", default: 0, null: false
    t.integer "messages_count", default: 0, null: false
    t.datetime "last_activity_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_topics_on_author_id"
    t.index ["client_id"], name: "index_topics_on_client_id"
    t.index ["project_id", "created_at"], name: "index_topics_on_project_id_and_created_at"
    t.index ["project_id", "status", "votes_score"], name: "index_topics_on_project_id_and_status_and_votes_score"
    t.index ["project_id"], name: "index_topics_on_project_id"
    t.index ["title"], name: "index_topics_on_title_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "user_preferences", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "theme_bg", default: "paper", null: false
    t.string "theme_accent", default: "orange", null: false
    t.string "email_frequency", default: "daily_digest", null: false
    t.time "quiet_hours_start", default: "2000-01-01 20:00:00", null: false
    t.time "quiet_hours_end", default: "2000-01-01 08:00:00", null: false
    t.time "work_day_start", default: "2000-01-01 09:00:00", null: false
    t.time "work_day_end", default: "2000-01-01 17:00:00", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_preferences_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.citext "email", null: false
    t.string "name", null: false
    t.string "time_zone", default: "UTC", null: false
    t.string "avatar_icon", default: "cat", null: false
    t.string "avatar_color", default: "orange", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "chains", "projects"
  add_foreign_key "chains", "sprints"
  add_foreign_key "chains", "topics"
  add_foreign_key "client_contacts", "clients"
  add_foreign_key "github_repositories", "integration_connections"
  add_foreign_key "github_repositories", "projects"
  add_foreign_key "identities", "users"
  add_foreign_key "integration_connections", "users", column: "connected_by_id"
  add_foreign_key "invitations", "projects"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "labels", "projects"
  add_foreign_key "meeting_digests", "meetings"
  add_foreign_key "meeting_participants", "meetings"
  add_foreign_key "meeting_participants", "users"
  add_foreign_key "meetings", "topics"
  add_foreign_key "meetings", "users", column: "organizer_id"
  add_foreign_key "notification_subscriptions", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "project_clients", "clients"
  add_foreign_key "project_clients", "projects"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "project_memberships", "users"
  add_foreign_key "pull_requests", "github_repositories"
  add_foreign_key "sessions", "users"
  add_foreign_key "sprints", "projects"
  add_foreign_key "task_labels", "labels"
  add_foreign_key "task_labels", "tasks"
  add_foreign_key "task_messages", "task_messages", column: "parent_id", on_delete: :nullify
  add_foreign_key "task_messages", "tasks"
  add_foreign_key "task_messages", "users", column: "author_id"
  add_foreign_key "task_pull_requests", "pull_requests"
  add_foreign_key "task_pull_requests", "tasks"
  add_foreign_key "tasks", "chains"
  add_foreign_key "tasks", "clients"
  add_foreign_key "tasks", "projects"
  add_foreign_key "tasks", "sprints"
  add_foreign_key "tasks", "topics"
  add_foreign_key "tasks", "users", column: "assignee_id"
  add_foreign_key "tasks", "users", column: "creator_id"
  add_foreign_key "time_entries", "tasks"
  add_foreign_key "time_entries", "users"
  add_foreign_key "time_off_allowances", "users"
  add_foreign_key "time_off_requests", "users"
  add_foreign_key "time_off_requests", "users", column: "approver_id"
  add_foreign_key "topic_messages", "topic_messages", column: "parent_id", on_delete: :nullify
  add_foreign_key "topic_messages", "topics"
  add_foreign_key "topic_messages", "users", column: "author_id"
  add_foreign_key "topic_votes", "topics"
  add_foreign_key "topic_votes", "users"
  add_foreign_key "topics", "clients"
  add_foreign_key "topics", "projects"
  add_foreign_key "topics", "users", column: "author_id"
  add_foreign_key "user_preferences", "users"
end
