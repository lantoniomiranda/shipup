# Topics (the conversation), chains/tasks (the work) and the time logged on it.
class CreateTopicsAndTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :topics do |t|
      t.references :project, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :client, foreign_key: true
      t.string :kind, null: false, default: "feature"
      t.string :status, null: false, default: "open"
      t.string :title, null: false
      t.text :body, null: false, default: ""
      t.integer :votes_score, null: false, default: 0
      t.integer :messages_count, null: false, default: 0
      t.datetime :last_activity_at
      t.timestamps
      t.index %i[project_id status votes_score]
      t.index %i[project_id created_at]
    end

    create_table :topic_votes do |t|
      t.references :topic, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :value, null: false
      t.timestamps
      t.index %i[topic_id user_id], unique: true
    end

    create_table :topic_messages do |t|
      t.references :topic, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false
      t.timestamps
      t.index %i[topic_id created_at]
    end

    create_table :chains do |t|
      t.references :project, null: false, foreign_key: true
      t.references :topic, foreign_key: true
      t.references :sprint, foreign_key: true
      t.string :title, null: false
      t.timestamps
    end

    create_table :tasks do |t|
      t.references :project, null: false, foreign_key: true
      t.references :sprint, foreign_key: true
      t.references :topic, foreign_key: true
      t.references :chain, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users }
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :client, foreign_key: true
      t.integer :number, null: false
      t.integer :chain_position
      t.string :title, null: false
      t.text :description
      t.string :status, null: false, default: "todo"
      t.integer :estimate_minutes
      t.date :due_on
      t.boolean :bug, null: false, default: false
      t.integer :position, null: false, default: 0
      t.datetime :completed_at
      t.timestamps
      t.index %i[project_id number], unique: true
      t.index %i[project_id sprint_id status position]
      t.index %i[chain_id chain_position], unique: true, where: "chain_id IS NOT NULL"
    end

    create_table :task_labels do |t|
      t.references :task, null: false, foreign_key: true
      t.references :label, null: false, foreign_key: true
      t.timestamps
      t.index %i[task_id label_id], unique: true
    end

    # A task has many entries; a running timer is an entry without ended_at.
    create_table :time_entries do |t|
      t.references :task, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.timestamps
      t.index %i[user_id started_at]
      t.index :user_id, unique: true, where: "ended_at IS NULL", name: "index_time_entries_one_running_per_user"
    end
  end
end
