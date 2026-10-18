# Look and feel, saved per person: background, accent (or any colour), font, density, text size,
# corners and a few effects. They land on <html> through the Appearance model.
class AppearancesController < ApplicationController
  layout "app"

  PERMITTED = %i[theme_bg theme_accent custom_accent font density text_size corners hard_shadows high_contrast reduce_motion].freeze

  def show
    @preference = Current.user.preference
  end

  def update
    preference = Current.user.preference
    if params[:reset]
      preference.reset_appearance!
      preference.update!(project_tab_order: [])
    else
      preference.update!(params.expect(preference: PERMITTED))
    end
    redirect_to appearance_path, notice: "Appearance saved.", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    redirect_to appearance_path, alert: "That look isn't available: #{error.record.errors.full_messages.to_sentence}.", status: :see_other
  end
end
