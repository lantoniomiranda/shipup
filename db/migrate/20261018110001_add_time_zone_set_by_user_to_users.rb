# Until someone picks a time zone themselves, it follows their browser.
class AddTimeZoneSetByUserToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :time_zone_set_by_user, :boolean, null: false, default: false
    execute "UPDATE users SET time_zone_set_by_user = TRUE WHERE time_zone <> 'UTC'" # an explicit choice already
  end

  def down
    remove_column :users, :time_zone_set_by_user
  end
end
