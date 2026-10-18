# Soft deletion: archived clients and tasks disappear from working views but keep their history.
class AddArchivingToClientsAndTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :archived_at, :datetime
    add_column :tasks, :archived_at, :datetime
  end
end
