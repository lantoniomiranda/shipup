class UserPreference < ApplicationRecord
  THEME_BACKGROUNDS = %w[paper mist sage night].freeze
  EMAIL_FREQUENCIES = %w[instant daily_digest weekly].freeze

  belongs_to :user

  validates :theme_bg, inclusion: { in: THEME_BACKGROUNDS }
  validates :theme_accent, inclusion: { in: Hued::HUES }
  validates :email_frequency, inclusion: { in: EMAIL_FREQUENCIES }
end
