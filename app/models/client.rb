class Client < ApplicationRecord
  belongs_to :workspace
  has_many :contacts, class_name: "ClientContact", dependent: :destroy
  has_many :project_clients, dependent: :destroy
  has_many :projects, through: :project_clients
  has_many :topics, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :workspace_id }

  # Creates the client (or reuses one with the same name) with its contact and extra emails.
  def self.onboard!(workspace:, name:, contact_name:, emails:)
    emails = emails.map { |email| email.to_s.strip.downcase }.reject(&:blank?).uniq
    raise ActiveRecord::RecordInvalid, new.tap { |client| client.errors.add(:base, "Add at least one email") } if emails.empty?

    transaction do
      client = workspace.clients.find_or_create_by!(name: name.to_s.strip)
      emails.each_with_index do |email, index|
        client.contacts.find_or_create_by!(email: email) { |contact| contact.name = index.zero? ? contact_name : contact_name.to_s.presence || email }
      end
      client
    end
  end

  def initials
    name.first(2).upcase
  end
end
