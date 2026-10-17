# Suggests meeting start times: for each of the next few working days, the hour (UTC)
# that falls inside the most invitees' local working hours.
class MeetingSlots
  Slot = Data.define(:starts_at, :covered, :total) do
    def label(duration)
      "#{starts_at.strftime("%a %-d %b")} · #{starts_at.strftime("%H:%M")} UTC · #{duration} min"
    end
  end

  def self.suggest(users, from: Time.current, days: 5)
    new(users, from).suggest(days)
  end

  def initialize(users, from)
    @users = users
    @from = from.utc
  end

  def suggest(days)
    working_days(days).map { |date| best_slot_on(date) }
  end

  private

  def working_days(count)
    (1..14).map { |offset| (@from + offset.days).to_date }.reject { |date| date.saturday? || date.sunday? }.first(count)
  end

  def best_slot_on(date)
    slots = (6..20).map { |hour| slot_at(Time.utc(date.year, date.month, date.day, hour)) }
    slots.max_by { |slot| [ slot.covered, -(slot.starts_at.hour - 12).abs ] } # prefer midday UTC on ties
  end

  def slot_at(time)
    Slot.new(starts_at: time, covered: @users.count { |user| working_at?(user, time) }, total: @users.size)
  end

  def working_at?(user, time)
    preference = user.preference or return false
    local = time.in_time_zone(user.time_zone)
    minutes = local.hour * 60 + local.min
    start = preference.work_day_start.hour * 60 + preference.work_day_start.min
    finish = preference.work_day_end.hour * 60 + preference.work_day_end.min
    minutes >= start && minutes < finish
  end
end
