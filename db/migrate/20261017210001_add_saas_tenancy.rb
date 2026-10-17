# Turns workspaces into SaaS tenants: lifecycle (status/plan/trial/seats), invite-only membership
# (invitations), and platform staff who run the backoffice (users.platform_admin).
class AddSaasTenancy < ActiveRecord::Migration[8.1]
  def change
    change_table :workspaces do |t|
      t.string :status, null: false, default: "active"
      t.string :plan, null: false, default: "trial"
      t.datetime :trial_ends_at
      t.integer :seats_limit
      t.datetime :suspended_at
      t.string :suspended_reason
      t.boolean :allow_domain_join, null: false, default: false
      t.index :status
    end

    # Domain-based auto join used to be implicit; keep it for workspaces that already relied on it.
    reversible do |direction|
      direction.up { execute "UPDATE workspaces SET allow_domain_join = TRUE WHERE email_domain IS NOT NULL" }
    end

    add_column :users, :platform_admin, :boolean, null: false, default: false

    create_table :invitations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :invited_by, foreign_key: { to_table: :users }
      t.citext :email, null: false
      t.string :role, null: false, default: "member"
      t.string :token, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.timestamps
      t.index :token, unique: true
      t.index %i[workspace_id email], unique: true, where: "accepted_at IS NULL AND revoked_at IS NULL", name: "index_invitations_one_pending_per_email"
      t.index :email
    end
  end
end
