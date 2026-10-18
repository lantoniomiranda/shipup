# Groups an ordered list of chat messages the way chat apps do: consecutive messages by the same
# author, at most WINDOW apart and on the same calendar day (in `time_zone`), share one header.
# A reply (a message quoting another) always starts a new group so its quote block has context.
#
#   MessageGrouping.new(messages, time_zone: user.time_zone).entries.each do |entry|
#     entry.message; entry.first_in_group?; entry.last_in_group?; entry.new_day?; entry.date
#   end
class MessageGrouping
  WINDOW = 5.minutes

  Entry = Struct.new(:message, :date, :first_in_group, :last_in_group, :new_day, keyword_init: true) do
    alias_method :first_in_group?, :first_in_group
    alias_method :last_in_group?, :last_in_group
    alias_method :new_day?, :new_day
  end

  def initialize(messages, time_zone: Time.zone.name)
    @messages = messages.to_a
    @zone = ActiveSupport::TimeZone[time_zone] || Time.zone
  end

  def entries
    @entries ||= build
  end

  private

  def build
    list = @messages.each_with_index.map do |message, index|
      previous = index.positive? ? @messages[index - 1] : nil
      date = date_of(message)
      Entry.new(message: message, date: date, new_day: previous.nil? || date_of(previous) != date,
                first_in_group: !continues?(previous, message), last_in_group: true)
    end
    list.each_cons(2) { |current, following| current.last_in_group = following.first_in_group }
    list
  end

  def continues?(previous, message)
    previous && previous.author_id == message.author_id && message.parent_id.nil? &&
      date_of(previous) == date_of(message) && message.created_at - previous.created_at <= WINDOW
  end

  def date_of(message) = message.created_at.in_time_zone(@zone).to_date
end
