class CreateTimeOffAndNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :time_off_allowances do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.integer :year, null: false
      t.integer :days, null: false
      t.timestamps
      t.index %i[user_id kind year], unique: true
    end

    create_table :time_off_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.references :approver, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.integer :working_days, null: false
      t.datetime :decided_at
      t.timestamps
      t.index %i[user_id starts_on]
      t.index %i[status starts_on]
    end

    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.references :subject, polymorphic: true, null: false
      t.string :kind, null: false
      t.datetime :read_at
      t.timestamps
      t.index %i[user_id read_at created_at]
    end
  end
end
