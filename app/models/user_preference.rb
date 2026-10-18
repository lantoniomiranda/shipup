class UserPreference < ApplicationRecord
  THEME_BACKGROUNDS = %w[paper mist sage night].freeze
  EMAIL_FREQUENCIES = %w[instant daily_digest weekly].freeze

  belongs_to :user

  validates :theme_bg, inclusion: { in: THEME_BACKGROUNDS }
  validates :theme_accent, inclusion: { in: Hued::HUES }
  validates :email_frequency, inclusion: { in: EMAIL_FREQUENCIES }
  validate :keybindings_are_usable

  # Saves the person's remappings ({ "board" => "g x" }). Blank values and values equal to the
  # default are dropped, so "reset" is simply an empty value.
  def remap_keybindings!(overrides)
    cleaned = overrides.to_h.transform_keys(&:to_s).select { |id, spec| spec.present? && Keybindings::SHORTCUTS.key?(id.to_sym) && spec != Keybindings.default_keys(id) }
    update!(keybindings: cleaned)
  end

  def reset_keybindings!
    update!(keybindings: {})
  end

  private

  def keybindings_are_usable
    Keybindings.validate(keybindings.to_h).each { |problem| errors.add(:keybindings, problem) }
  end
end
