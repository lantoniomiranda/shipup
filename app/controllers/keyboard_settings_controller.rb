# Settings → Keyboard shortcuts: remap any (non-fixed) shortcut, only to combinations that work
# in every browser. Validation lives in Keybindings.
class KeyboardSettingsController < ApplicationController
  layout "app"

  def show
    @overrides = preference.keybindings
  end

  def update
    submitted = params.fetch(:keybindings, {}).permit(*Keybindings.customizable.map { |entry| entry[:id].to_s }).to_h
    preference.remap_keybindings!(submitted)
    redirect_to keyboard_settings_path, notice: "Shortcuts saved.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    @overrides = submitted.select { |id, spec| spec != Keybindings.default_keys(id) }
    @problems = preference.errors.full_messages_for(:keybindings).map { |message| message.delete_prefix("Keybindings ") }
    render :show, status: :unprocessable_content
  end

  # Back to the defaults.
  def destroy
    preference.reset_keybindings!
    redirect_to keyboard_settings_path, notice: "Shortcuts reset to the defaults.", status: :see_other
  end

  private

  def preference = Current.user.preference
end
