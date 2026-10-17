# Lets teammates signing in with the same company email land in the same workspace.
class AddEmailDomainToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :email_domain, :string
    add_index :workspaces, :email_domain, unique: true
  end
end
