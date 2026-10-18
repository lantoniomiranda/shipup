require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:ines) }

  test "home greets the user and lists the active projects" do
    get root_path
    assert_response :success
    assert_select "h1", /Inês/
    assert_select ".project-card h2", text: "Apollo Gateway"
    assert_select ".project-card__stats", /1 open topic.*2 tasks/
  end

  test "each project card opens that project's topics" do
    get root_path
    assert_select "a.project-card[href=?]", project_topics_path(projects(:apollo))
  end

  test "shows sprint progress as a lit XP bar" do
    get root_path
    assert_select ".xp__labels strong", "33% XP"
    assert_select ".xp__segment--on", Project.xp_segments_lit(33)
  end

  test "completed filter shows only completed projects" do
    projects(:apollo).completed!
    get root_path(status: "completed")
    assert_select ".project-card h2", "Apollo Gateway"
    get root_path
    assert_select ".project-card h2", count: 0
  end

  test "only admins see the new-project controls" do
    get root_path
    assert_select ".btn--primary", /New project/

    sign_out
    sign_in_as users(:jonas)
    get root_path
    assert_select ".btn--primary", count: 0
  end

  test "projects the user was not invited to never show up" do
    Project.create!(name: "Secret", key: "SEC")
    sign_out
    sign_in_as users(:jonas)
    get root_path
    assert_select ".project-card h2", text: "Secret", count: 0
    assert_select ".project-card h2", text: "Apollo Gateway"
  end

  test "the top bar shows the running timer for the signed-in user" do
    tasks(:rate_limiting).time_entries.create!(user: users(:ines), started_at: 1.hour.ago)
    get root_path
    assert_select ".timer-pill", /APO-97/
  end
end

class TopicAwaitingReplyTest < ActiveSupport::TestCase
  test "counts open topics where someone else spoke last in a conversation you joined" do
    topic = topics(:refresh_tokens)
    topic.messages.create!(author: users(:ines), body: "I'll look.")
    assert_empty Topic.awaiting_reply_from(users(:ines)).where(id: topic.id)

    topic.messages.create!(author: users(:jonas), body: "Any update?")
    assert_includes Topic.awaiting_reply_from(users(:ines)), topic
  end

  test "ignores closed topics and topics you were never part of" do
    topic = topics(:refresh_tokens)
    assert_not_includes Topic.awaiting_reply_from(users(:ines)), topic
    topic.messages.create!(author: users(:ines), body: "Hi")
    topic.messages.create!(author: users(:jonas), body: "Ping")
    topic.canceled!
    assert_not_includes Topic.awaiting_reply_from(users(:ines)), topic
  end
end
