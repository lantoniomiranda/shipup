# People, how they sign in, and the workspaces they belong to.
class CreateIdentityAndWorkspaces < ActiveRecord::Migration[8.1]
  def change
    enable_extension "citext"

    create_table :users do |t|
      t.citext :email, null: false
      t.string :name, null: false
      t.string :time_zone, null: false, default: "UTC"
      t.string :avatar_icon, null: false, default: "cat"
      t.string :avatar_color, null: false, default: "orange"
      t.timestamps
      t.index :email, unique: true
    end

    # OAuth is the only way in: one row per external account linked to a user.
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.citext :email, null: false
      t.timestamps
      t.index %i[provider uid], unique: true
    end

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    create_table :workspaces do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :meeting_provider
      t.timestamps
      t.index :slug, unique: true
    end

    create_table :memberships do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.timestamps
      t.index %i[workspace_id user_id], unique: true
    end

    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :theme_bg, null: false, default: "paper"
      t.string :theme_accent, null: false, default: "orange"
      t.string :email_frequency, null: false, default: "daily_digest"
      t.time :quiet_hours_start, null: false, default: "20:00"
      t.time :quiet_hours_end, null: false, default: "08:00"
      t.time :work_day_start, null: false, default: "09:00"
      t.time :work_day_end, null: false, default: "17:00"
      t.timestamps
    end

    # One row per (user, event kind) the user has switched on or off.
    create_table :notification_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
      t.index %i[user_id kind], unique: true
    end
  end
end
