require "test_helper"

class TopicsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @topic = topics(:refresh_tokens)
    sign_in_as users(:ines)
  end

  test "lists topics with their score, author and reply count" do
    @project.topics.create!(author: users(:ines), title: "Dark mode", votes_score: 30, kind: "feature")
    get project_topics_path(@project)

    assert_response :success
    assert_select ".topic-row__title", count: 2
    assert_select ".topic-row:first-child .topic-row__title", "Dark mode" # highest score first
    assert_select ".votes__score", "+30"
    assert_select ".tab--active", /Topics/
  end

  test "filters by kind and status, and counts each bucket" do
    @project.topics.create!(author: users(:ines), title: "A feature", kind: "feature")
    @project.topics.create!(author: users(:ines), title: "Old idea", kind: "feature", status: "canceled")

    get project_topics_path(@project, filter: "issues")
    assert_select ".topic-row__title", count: 1
    assert_select ".chip--active", /Issues 1/

    get project_topics_path(@project, filter: "canceled")
    assert_select ".topic-row__title", "Old idea"
    assert_select ".topic-row--canceled", 1
  end

  test "can sort by newest" do
    newer = @project.topics.create!(author: users(:ines), title: "Brand new", kind: "issue", votes_score: -5)
    get project_topics_path(@project, sort: "new")
    assert_select ".topic-row:first-child .topic-row__title", newer.title
  end

  test "shows the opening text first, then replies, and who is in the chat" do
    @topic.messages.create!(author: users(:ines), body: "On it.")
    get project_topic_path(@project, @topic)

    assert_response :success
    assert_select "h1", @topic.title
    assert_select ".message", 2
    assert_select ".message:first-child .message__body p", /401s exactly 24h/
    assert_select ".participants li", 2
    assert_select ".participants li:first-child em", "Opened"
    assert_select ".participants li:last-child em", "Replied"
  end

  test "creates a topic authored by the current user" do
    assert_difference "@project.topics.count", 1 do
      post project_topics_path(@project), params: { topic: { kind: "issue", title: "Login loops", body: "Details" } }
    end
    topic = @project.topics.order(:id).last
    assert_redirected_to project_topic_path(@project, topic)
    assert_equal users(:ines), topic.author
    assert topic.issue?
  end

  test "rejects a topic without a title" do
    assert_no_difference "Topic.count" do
      post project_topics_path(@project), params: { topic: { kind: "feature", title: "" } }
    end
    assert_response :unprocessable_content
  end

  test "ignores a client that does not belong to the project" do
    stranger = workspaces(:orbit).clients.create!(name: "Stranger")
    post project_topics_path(@project), params: { topic: { kind: "feature", title: "Hello", client_id: stranger.id } }
    assert_nil @project.topics.find_by(title: "Hello").client
  end

  test "the new-topic form lists the project's clients" do
    client = workspaces(:orbit).clients.create!(name: "Northwind")
    @project.project_clients.create!(client: client)
    get new_project_topic_path(@project)
    assert_select ".choice__option", /Client: Northwind/
    assert_select ".choice__option", /Internal idea/
  end

  test "suggests similar topics as the title is typed" do
    get similar_project_topics_path(@project, q: "Refresh tokens expiring")
    assert_response :success
    assert_select ".similar strong", @topic.title
    assert_select ".similar--best .similar__read"
  end

  test "does not search for very short queries" do
    get similar_project_topics_path(@project, q: "re")
    assert_select ".similar", count: 0
  end

  test "another workspace's project is a 404" do
    other = Workspace.create!(name: "Other Co").projects.create!(name: "Secret", key: "SEC")
    get project_topics_path(other)
    assert_response :not_found
  end

  test "visiting the project redirects to its topics" do
    get project_path(@project)
    assert_redirected_to project_topics_path(@project)
  end
end

class TopicVotesAndMessagesTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @topic = topics(:refresh_tokens)
    sign_in_as users(:ines)
  end

  test "upvoting records one vote and refreshes the score" do
    post project_topic_vote_path(@project, @topic, value: 1), headers: { "HTTP_REFERER" => project_topics_url(@project) }
    assert_redirected_to project_topics_url(@project)
    assert_equal 1, @topic.reload.votes_score
    assert_equal 1, @topic.vote_by(users(:ines)).value
  end

  test "voting twice retracts the vote" do
    2.times { post project_topic_vote_path(@project, @topic, value: 1) }
    assert_equal 0, @topic.reload.votes_score
  end

  test "values are clamped to a single up or down vote" do
    post project_topic_vote_path(@project, @topic, value: 99)
    assert_equal 1, @topic.reload.votes_score
  end

  test "posting a reply adds it to the chat" do
    assert_difference "@topic.messages.count", 1 do
      post project_topic_messages_path(@project, @topic), params: { message: { body: "Looking now" } }
    end
    assert_response :see_other
    assert_equal users(:ines), @topic.messages.last.author
    assert_equal 1, @topic.reload.messages_count
  end

  test "an empty reply is rejected" do
    assert_no_difference "TopicMessage.count" do
      post project_topic_messages_path(@project, @topic), params: { message: { body: "  " } }
    end
    assert_redirected_to project_topic_path(@project, @topic)
  end
end
