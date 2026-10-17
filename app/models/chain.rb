# Tasks that must ship in order; finishing one unlocks the next.
class Chain < ApplicationRecord
  belongs_to :project
  belongs_to :topic, optional: true
  belongs_to :sprint, optional: true
  has_many :tasks, -> { order(:chain_position) }, dependent: :destroy

  validates :title, presence: true

  def total_estimate_minutes
    tasks.sum(:estimate_minutes)
  end
end
