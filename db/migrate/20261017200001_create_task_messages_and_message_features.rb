# Task chat, plus reply / edit / remove support for topic messages. Both chats share the same shape:
# a message can quote an earlier one in its thread (parent), be edited (edited_at) and be removed
# without breaking the replies that quote it (deleted_at, soft delete).
class CreateTaskMessagesAndMessageFeatures < ActiveRecord::Migration[8.1]
  def change
    create_table :task_messages do |t|
      t.references :task, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :parent, foreign_key: { to_table: :task_messages, on_delete: :nullify }
      t.text :body, null: false, default: ""
      t.datetime :edited_at
      t.datetime :deleted_at
      t.timestamps
      t.index %i[task_id created_at]
    end

    change_table :topic_messages do |t|
      t.references :parent, foreign_key: { to_table: :topic_messages, on_delete: :nullify }
      t.datetime :edited_at
      t.datetime :deleted_at
    end
    change_column_default :topic_messages, :body, from: nil, to: ""
  end
end
