class ClientContact < ApplicationRecord
  belongs_to :client

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { scope: :client_id }, format: { with: URI::MailTo::EMAIL_REGEXP }
end
