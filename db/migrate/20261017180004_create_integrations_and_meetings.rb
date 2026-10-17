# Third-party connections (Zoom, Google Meet, GitHub) and the meetings/PRs they produce.
class CreateIntegrationsAndMeetings < ActiveRecord::Migration[8.1]
  def change
    # One authorised account per provider per workspace. Tokens are encrypted by the model.
    create_table :integration_connections do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :connected_by, null: false, foreign_key: { to_table: :users }
      t.string :provider, null: false
      t.string :external_account, null: false
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.string :scopes
      t.timestamps
      t.index %i[workspace_id provider], unique: true
    end

    create_table :meetings do |t|
      t.references :topic, null: false, foreign_key: true
      t.references :organizer, null: false, foreign_key: { to_table: :users }
      t.string :provider, null: false
      t.string :external_id
      t.string :join_url
      t.datetime :starts_at, null: false
      t.integer :duration_minutes, null: false, default: 30
      t.boolean :transcribe, null: false, default: true
      t.timestamps
      t.index %i[topic_id starts_at]
      t.index %i[provider external_id], unique: true, where: "external_id IS NOT NULL"
    end

    create_table :meeting_participants do |t|
      t.references :meeting, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :requirement, null: false, default: "required"
      t.timestamps
      t.index %i[meeting_id user_id], unique: true
    end

    # What the provider sent back after the call: recording, transcript and a summary.
    create_table :meeting_digests do |t|
      t.references :meeting, null: false, foreign_key: true, index: { unique: true }
      t.text :summary
      t.text :transcript
      t.string :recording_url
      t.integer :recording_seconds
      t.timestamps
    end

    create_table :github_repositories do |t|
      t.references :project, null: false, foreign_key: true
      t.references :integration_connection, null: false, foreign_key: true
      t.bigint :external_id, null: false
      t.string :full_name, null: false
      t.timestamps
      t.index %i[project_id external_id], unique: true
      t.index :external_id
    end

    create_table :pull_requests do |t|
      t.references :github_repository, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :title, null: false
      t.string :state, null: false, default: "open"
      t.string :url, null: false
      t.string :author_login
      t.datetime :merged_at
      t.timestamps
      t.index %i[github_repository_id number], unique: true
    end

    create_table :task_pull_requests do |t|
      t.references :task, null: false, foreign_key: true
      t.references :pull_request, null: false, foreign_key: true
      t.timestamps
      t.index %i[task_id pull_request_id], unique: true
    end
  end
end
