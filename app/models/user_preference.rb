class UserPreference < ApplicationRecord
  THEME_BACKGROUNDS = %w[paper mist sage night system].freeze # "system" follows the OS light/dark setting
  ACCENTS = (Hued::HUES + %w[custom]).freeze
  FONTS = %w[exo inter atkinson serif mono system].freeze
  DENSITIES = %w[compact comfortable spacious].freeze
  TEXT_SIZES = %w[small default large larger].freeze
  CORNERS = %w[square soft round].freeze
  HEX_COLOR = /\A#\h{6}\z/
  DEFAULT_APPEARANCE = { theme_bg: "paper", theme_accent: "orange", font: "exo", density: "comfortable", text_size: "default",
                         corners: "square", custom_accent: nil, hard_shadows: true, high_contrast: false, reduce_motion: false }.freeze
  EMAIL_FREQUENCIES = %w[instant daily_digest weekly].freeze

  belongs_to :user

  validates :theme_bg, inclusion: { in: THEME_BACKGROUNDS }
  validates :theme_accent, inclusion: { in: ACCENTS }
  validates :custom_accent, format: { with: HEX_COLOR }, allow_nil: true
  validates :custom_accent, presence: true, if: -> { theme_accent == "custom" }
  validates :font, inclusion: { in: FONTS }
  validates :density, inclusion: { in: DENSITIES }
  validates :text_size, inclusion: { in: TEXT_SIZES }
  validates :corners, inclusion: { in: CORNERS }
  validate :tab_order_is_known
  validates :email_frequency, inclusion: { in: EMAIL_FREQUENCIES }
  validate :keybindings_are_usable

  # Saves the person's remappings ({ "board" => "g x" }). Blank values and values equal to the
  # default are dropped, so "reset" is simply an empty value.
  def remap_keybindings!(overrides)
    cleaned = overrides.to_h.transform_keys(&:to_s).select { |id, spec| spec.present? && Keybindings::SHORTCUTS.key?(id.to_sym) && spec != Keybindings.default_keys(id) }
    update!(keybindings: cleaned)
  end

  def reset_appearance!
    update!(DEFAULT_APPEARANCE)
  end

  # Saves the person's order of the project tabs (Topics, Backlog, Board…). Unknown ids are ignored
  # and missing ones are appended in the default order when the tabs are shown.
  def reorder_project_tabs!(keys)
    update!(project_tab_order: keys.map(&:to_s) & ProjectTabs::KEYS)
  end

  def reset_keybindings!
    update!(keybindings: {})
  end

  private

  def tab_order_is_known
    errors.add(:project_tab_order, "has unknown tabs") unless (project_tab_order - ProjectTabs::KEYS).empty?
  end

  def keybindings_are_usable
    Keybindings.validate(keybindings.to_h).each { |problem| errors.add(:keybindings, problem) }
  end
end
