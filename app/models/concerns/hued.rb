# Models that carry one of the design palette's hues (project cards, labels, avatars).
module Hued
  extend ActiveSupport::Concern

  HUES = %w[orange mustard teal plum blue].freeze

  included do
    validates :color, inclusion: { in: HUES }
  end
end
