require "test_helper"

class MessageGroupingTest < ActiveSupport::TestCase
  Msg = Struct.new(:author_id, :created_at, :parent_id)

  def msg(author, at, parent: nil) = Msg.new(author, Time.utc(2026, 10, 14, *at), parent)

  def flags(messages, **opts)
    MessageGrouping.new(messages, time_zone: "UTC", **opts).entries.map { |e| [ e.first_in_group?, e.last_in_group? ] }
  end

  test "consecutive messages by one author within the window form a group" do
    list = [ msg(1, [ 10, 0 ]), msg(1, [ 10, 3 ]), msg(1, [ 10, 7 ]) ]
    assert_equal [ [ true, false ], [ false, false ], [ false, true ] ], flags(list)
  end

  test "a gap longer than the window starts a new group" do
    assert_equal [ [ true, true ], [ true, true ] ], flags([ msg(1, [ 10, 0 ]), msg(1, [ 10, 6 ]) ])
  end

  test "a different author starts a new group" do
    assert_equal [ [ true, true ], [ true, true ], [ true, true ] ], flags([ msg(1, [ 10, 0 ]), msg(2, [ 10, 1 ]), msg(1, [ 10, 2 ]) ])
  end

  test "a reply always starts a new group, and the next message can follow it" do
    list = [ msg(1, [ 10, 0 ]), msg(1, [ 10, 1 ], parent: 9), msg(1, [ 10, 2 ]) ]
    assert_equal [ [ true, true ], [ true, false ], [ false, true ] ], flags(list)
  end

  test "a new calendar day in the viewer's zone splits groups and flags the day" do
    late = Msg.new(1, Time.utc(2026, 10, 14, 23, 58), nil)
    early = Msg.new(1, Time.utc(2026, 10, 15, 0, 1), nil)
    entries = MessageGrouping.new([ late, early ], time_zone: "UTC").entries
    assert_equal [ true, true ], entries.map(&:first_in_group?)
    assert_equal [ true, true ], entries.map(&:new_day?)

    lisbon = MessageGrouping.new([ late, early ], time_zone: "Pacific/Auckland").entries
    assert_equal [ true, false ], lisbon.map(&:new_day?)
  end

  test "empty list" do
    assert_empty MessageGrouping.new([]).entries
  end
end
