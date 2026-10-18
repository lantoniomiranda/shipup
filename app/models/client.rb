class Client < ApplicationRecord
  has_many :contacts, class_name: "ClientContact", dependent: :destroy
  has_many :project_clients, dependent: :destroy
  has_many :projects, through: :project_clients
  has_many :topics, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  # Creates the client (or reuses one with the same name) with its contact and extra emails.
  # A client that was archived earlier comes back.
  def self.onboard!(name:, contact_name:, emails:)
    emails = emails.map { |email| email.to_s.strip.downcase }.reject(&:blank?).uniq
    raise ActiveRecord::RecordInvalid, new.tap { |client| client.errors.add(:base, I18n.t("model_errors.one_email")) } if emails.empty?

    transaction do
      client = find_or_create_by!(name: name.to_s.strip)
      client.restore! if client.archived?
      emails.each_with_index do |email, index|
        client.contacts.find_or_create_by!(email: email) { |contact| contact.name = index.zero? ? contact_name : contact_name.to_s.presence || email }
      end
      client
    end
  end

  def archived? = archived_at.present?

  # Soft delete: the client leaves every picker and list but its topics keep pointing at it.
  def archive! = update!(archived_at: Time.current)

  def restore! = update!(archived_at: nil)

  def initials
    name.first(2).upcase
  end
end
