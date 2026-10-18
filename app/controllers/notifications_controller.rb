class NotificationsController < ApplicationController
  layout "app"

  def index
    @notifications = Current.user.notifications.includes(:actor, :subject).recent.limit(50)
  end

  # Opening a notification marks it read and takes you to what it is about.
  def show
    notification = Current.user.notifications.find(params[:id])
    notification.read!
    target = helpers.notification_target(notification)
    redirect_to target || notifications_path, status: :see_other
  end

  def read_all
    Notification.mark_all_read(Current.user)
    redirect_to notifications_path, notice: "All caught up.", status: :see_other
  end
end
