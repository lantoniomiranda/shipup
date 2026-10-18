# The signed-in user's profile, avatar and notification preferences.
class AccountsController < ApplicationController
  layout "app"

  def show
    @user = Current.user
    @roles = role_summary(@user)
  end

  def update
    @user = Current.user
    User.transaction do
      @user.update!(params.expect(user: %i[name avatar_icon avatar_color]))
      @user.preference.update!(params.expect(preference: %i[email_frequency quiet_hours_start quiet_hours_end]))
      @user.update_notification_subscriptions(params.fetch(:notifications, {}).permit(*NotificationSubscription::KINDS).to_h)
    end
    redirect_to account_path, notice: t("account.saved"), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @roles = role_summary(@user)
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render :show, status: :unprocessable_content
  end

  private

  # "Manager · Apollo gateway, mobile atlas"
  def role_summary(user)
    managed = user.project_memberships.admin.includes(:project).map { |membership| membership.project.name.downcase }
    role = user.superadmin? ? t("roles.superadmin") : (managed.any? ? t("roles.admin") : t("roles.member"))
    managed.any? ? "#{role} · #{managed.to_sentence(two_words_connector: ", ", last_word_connector: ", ")}" : role
  end
end
