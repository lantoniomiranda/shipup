# Settings → Notifications: which events email you, how often, and the quiet hours.
# (The inbox of notifications themselves is NotificationsController.)
class NotificationSettingsController < ApplicationController
  layout "settings"

  def show
    @user = Current.user
  end

  def update
    @user = Current.user
    User.transaction do
      @user.preference.update!(params.expect(preference: %i[email_frequency quiet_hours_start quiet_hours_end]))
      @user.update_notification_subscriptions(params.fetch(:notifications, {}).permit(*NotificationSubscription::KINDS).to_h)
    end
    redirect_to notification_setting_path, notice: t("account.saved"), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render :show, status: :unprocessable_content
  end
end
