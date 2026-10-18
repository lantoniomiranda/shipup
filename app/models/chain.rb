# Tasks that must ship in order; finishing one unlocks the next.
class Chain < ApplicationRecord
  belongs_to :project
  belongs_to :topic, optional: true
  belongs_to :sprint, optional: true
  has_many :tasks, -> { order(:chain_position) }, dependent: :destroy

  validates :title, presence: true

  # Creates a chain and its ordered steps atomically. `steps` is a list of hashes with
  # :title, :description, :assignee_id and :estimate_days; blank-titled steps are dropped.
  def self.create_with_steps!(project:, creator:, steps:, **attributes)
    steps = steps.reject { |step| step[:title].blank? }
    chain = project.chains.new(**attributes)
    chain.errors.add(:base, I18n.t("model_errors.one_step")) if steps.empty?
    raise ActiveRecord::RecordInvalid, chain if chain.errors.any?

    transaction do
      chain.save!
      steps.each.with_index(1) do |step, position|
        project.tasks.create!(
          chain: chain, chain_position: position, creator: creator, topic: chain.topic, sprint: chain.sprint,
          title: step[:title], description: step[:description], assignee_id: step[:assignee_id].presence,
          estimate_days: step[:estimate_days]
        )
      end
      chain
    end
  end

  def total_estimate_minutes
    tasks.sum(:estimate_minutes)
  end
end
