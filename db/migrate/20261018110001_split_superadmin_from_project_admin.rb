# Two levels of admin: the superadmin (configured by email in SUPERADMIN_EMAILS, never stored) and
# per-project admins (what project "managers" are now called).
class SplitSuperadminFromProjectAdmin < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE project_memberships SET role = 'admin' WHERE role = 'manager'"
    execute "UPDATE invitations SET role = 'admin' WHERE role = 'manager'"
    remove_column :users, :admin
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
