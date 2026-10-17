# Projects and everything that hangs directly off them.
class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false
      t.text :description
      t.string :color, null: false, default: "orange"
      t.string :icon, null: false, default: "rocket"
      t.string :status, null: false, default: "active"
      t.integer :position, null: false, default: 0
      t.integer :last_task_number, null: false, default: 0
      t.datetime :last_activity_at
      t.timestamps
      t.index %i[workspace_id key], unique: true
      t.index %i[workspace_id status position]
    end

    create_table :project_memberships do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.timestamps
      t.index %i[project_id user_id], unique: true
    end

    create_table :sprints do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :number, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.timestamps
      t.index %i[project_id number], unique: true
    end

    create_table :clients do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
      t.index %i[workspace_id name], unique: true
    end

    create_table :client_contacts do |t|
      t.references :client, null: false, foreign_key: true
      t.string :name, null: false
      t.citext :email, null: false
      t.timestamps
      t.index %i[client_id email], unique: true
    end

    create_table :project_clients do |t|
      t.references :project, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.string :status, null: false, default: "invite_pending"
      t.timestamps
      t.index %i[project_id client_id], unique: true
    end

    create_table :labels do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color, null: false, default: "orange"
      t.timestamps
      t.index %i[project_id name], unique: true
    end
  end
end
