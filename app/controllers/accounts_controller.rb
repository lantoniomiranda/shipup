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
      @user.update!(user_params)
      @user.preference.update!(params.expect(preference: %i[email_frequency quiet_hours_start quiet_hours_end]))
      @user.update_notification_subscriptions(params.fetch(:notifications, {}).permit(*NotificationSubscription::KINDS).to_h)
    end
    redirect_to account_path, notice: t("account.saved"), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @user.restore_attributes(%w[time_zone time_zone_set_by_user]) # the page still needs a valid zone to render
    @roles = role_summary(@user)
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render :show, status: :unprocessable_content
  end

  private

  # Picking a zone is an explicit choice (stop following the browser); ticking "automatic" resumes following it.
  def user_params
    attrs = params.expect(user: %i[name avatar_icon avatar_color time_zone time_zone_auto]).to_h
    auto = attrs.delete("time_zone_auto") == "1"
    attrs.delete("time_zone") if auto || attrs["time_zone"].blank?
    attrs.merge("time_zone_set_by_user" => !auto)
  end

  # "Manager · Apollo gateway, mobile atlas"
  def role_summary(user)
    managed = user.project_memberships.admin.includes(:project).map { |membership| membership.project.name.downcase }
    role = user.superadmin? ? t("roles.superadmin") : (managed.any? ? t("roles.admin") : t("roles.member"))
    managed.any? ? "#{role} · #{managed.to_sentence(two_words_connector: ", ", last_word_connector: ", ")}" : role
  end
end
