# Your look: background and accent. Saved per user, applied through data attributes on <html>.
class AppearancesController < ApplicationController
  layout "app"

  def show
    @preference = Current.user.preference
  end

  def update
    preference = Current.user.preference
    if params[:reset]
      preference.update!(theme_bg: "paper", theme_accent: "orange")
    else
      preference.update!(params.expect(preference: %i[theme_bg theme_accent]))
    end
    redirect_to appearance_path, notice: t("appearance.saved"), status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to appearance_path, alert: t("appearance.invalid"), status: :see_other
  end
end
