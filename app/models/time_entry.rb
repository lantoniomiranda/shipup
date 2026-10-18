class TimeEntry < ApplicationRecord
  belongs_to :task
  belongs_to :user

  validates :started_at, presence: true
  validate :ends_after_start

  scope :running, -> { where(ended_at: nil) }

  def running?
    ended_at.nil?
  end

  def seconds(now: Time.current)
    ((ended_at || now) - started_at).to_i
  end

  def stop!(at: Time.current)
    update!(ended_at: at)
  end

  private

  def ends_after_start
    errors.add(:ended_at, I18n.t("model_errors.ended_after_start")) if ended_at && started_at && ended_at < started_at
  end
end
