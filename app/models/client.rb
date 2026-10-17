class Client < ApplicationRecord
  belongs_to :workspace
  has_many :contacts, class_name: "ClientContact", dependent: :destroy
  has_many :project_clients, dependent: :destroy
  has_many :projects, through: :project_clients
  has_many :topics, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :workspace_id }

  def initials
    name.first(2).upcase
  end
end
