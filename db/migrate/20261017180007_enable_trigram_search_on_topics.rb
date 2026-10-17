# Powers "Similar topics" suggestions while someone is writing a new topic.
class EnableTrigramSearchOnTopics < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"
    add_index :topics, :title, using: :gin, opclass: :gin_trgm_ops, name: "index_topics_on_title_trgm"
  end
end
