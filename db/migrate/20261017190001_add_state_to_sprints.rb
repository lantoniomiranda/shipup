# A sprint is planned, active or completed, and a project can have only one active sprint
# (enforced by a partial unique index, not just by validation).
class AddStateToSprints < ActiveRecord::Migration[8.1]
  def up
    add_column :sprints, :state, :string, null: false, default: "planned"
    add_column :sprints, :goal, :text
    add_column :sprints, :completed_at, :datetime

    # Backfill from the old date-based meaning: one running sprint per project, the past is completed.
    execute <<~SQL.squish
      UPDATE sprints SET state = 'completed', completed_at = ends_on WHERE ends_on < CURRENT_DATE
    SQL
    execute <<~SQL.squish
      UPDATE sprints SET state = 'active' WHERE id IN (
        SELECT DISTINCT ON (project_id) id FROM sprints
        WHERE starts_on <= CURRENT_DATE AND ends_on >= CURRENT_DATE ORDER BY project_id, starts_on DESC
      )
    SQL

    add_index :sprints, :project_id, unique: true, where: "state = 'active'", name: "index_sprints_one_active_per_project"
  end

  def down
    remove_index :sprints, name: "index_sprints_one_active_per_project"
    remove_column :sprints, :completed_at
    remove_column :sprints, :goal
    remove_column :sprints, :state
  end
end
