# Instance-wide choices made by a superadmin. There is one row per deploy: use `Setting.current`.
class Setting < ApplicationRecord
  MEETING_PROVIDERS = %w[zoom google_meet].freeze

  validates :meeting_provider, inclusion: { in: MEETING_PROVIDERS }, allow_nil: true

  def self.current
    first || create!
  end

  def self.meeting_provider = current.meeting_provider
end
