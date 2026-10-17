class Label < ApplicationRecord
  include Hued

  belongs_to :project
  has_many :task_labels, dependent: :destroy
  has_many :tasks, through: :task_labels

  validates :name, presence: true, uniqueness: { scope: :project_id }
end
