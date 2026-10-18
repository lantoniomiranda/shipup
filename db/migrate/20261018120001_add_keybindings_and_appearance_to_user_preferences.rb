# Per-person customisation: remapped keyboard shortcuts, the order of the project tabs, and the
# extra appearance settings (font, density, corners, custom accent colour…).
class AddKeybindingsAndAppearanceToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    change_table :user_preferences do |t|
      t.jsonb :keybindings, null: false, default: {}
      t.string :project_tab_order, array: true, null: false, default: []

      t.string :font, null: false, default: "exo"
      t.string :density, null: false, default: "comfortable"
      t.string :text_size, null: false, default: "default"
      t.string :corners, null: false, default: "square"
      t.string :custom_accent
      t.boolean :hard_shadows, null: false, default: true
      t.boolean :high_contrast, null: false, default: false
      t.boolean :reduce_motion, null: false, default: false
    end
  end
end
