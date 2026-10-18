# ShipUp is deployed once per customer, so there are no workspaces (tenants), no platform staff and
# no backoffice. Access is decided per project: people are invited to a project by email, and
# `users.admin` marks the few who may create projects and connect integrations.
class RemoveMultiTenancy < ActiveRecord::Migration[8.1]
  def up
    # Existing workspaces are merged into the one instance. The unique indexes added below fail
    # loudly if two of them used the same project key, client name or integration.
    add_column :users, :admin, :boolean, null: false, default: false
    execute "UPDATE users SET admin = TRUE WHERE platform_admin OR id IN (SELECT user_id FROM memberships WHERE role = 'admin')"
    remove_column :users, :platform_admin

    # Instance-wide settings (one row) replace what used to live on the workspace.
    create_table :settings do |t|
      t.string :meeting_provider
      t.timestamps
    end
    execute "INSERT INTO settings (meeting_provider, created_at, updated_at) SELECT meeting_provider, NOW(), NOW() FROM workspaces WHERE meeting_provider IS NOT NULL ORDER BY id LIMIT 1"

    # Invitations now grant access to one project instead of a workspace.
    drop_table :invitations
    create_table :invitations do |t|
      t.references :project, null: false, foreign_key: true
      t.references :invited_by, foreign_key: { to_table: :users }
      t.citext :email, null: false
      t.string :role, null: false, default: "member"
      t.string :token, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.timestamps
      t.index :token, unique: true
      t.index %i[project_id email], unique: true, where: "accepted_at IS NULL AND revoked_at IS NULL", name: "index_invitations_one_pending_per_email"
      t.index :email
    end

    drop_table :memberships

    remove_reference :integration_connections, :workspace, foreign_key: true, index: true
    add_index :integration_connections, :provider, unique: true

    remove_reference :clients, :workspace, foreign_key: true, index: true
    add_index :clients, :name, unique: true

    remove_reference :projects, :workspace, foreign_key: true, index: true
    add_index :projects, :key, unique: true
    add_index :projects, %i[status position]

    drop_table :workspaces
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Multi-tenancy was removed on purpose."
  end
end
