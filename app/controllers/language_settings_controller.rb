# Settings → Language and time: time zone (following the browser or chosen) and working hours.
# The language itself is remembered per browser by LocalesController.
class LanguageSettingsController < ApplicationController
  layout "settings"

  def show
    @user = Current.user
  end

  def update
    @user = Current.user
    User.transaction do
      @user.update!(user_params)
      @user.preference.update!(params.expect(preference: %i[work_day_start work_day_end]))
    end
    redirect_to language_setting_path, notice: t("language_settings.saved"), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    @user.restore_attributes(%w[time_zone time_zone_set_by_user]) # the page still needs a valid zone to render
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render :show, status: :unprocessable_content
  end

  private

  # Picking a zone is an explicit choice (stop following the browser); ticking "automatic" resumes following it.
  def user_params
    attrs = params.expect(user: %i[time_zone time_zone_auto]).to_h
    auto = attrs.delete("time_zone_auto") == "1"
    attrs.delete("time_zone") if auto || attrs["time_zone"].blank?
    attrs.merge("time_zone_set_by_user" => !auto)
  end
end
