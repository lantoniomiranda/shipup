require "test_helper"

class TopicWorkflowTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json" }.freeze

  setup do
    @project = projects(:apollo)
    @topic = topics(:refresh_tokens)
    sign_in_as users(:ines)
  end

  test "the topic page offers Move on and Meet about it" do
    get project_topic_path(@project, @topic)
    assert_select ".menu__item strong", "Create task"
    assert_select ".menu__item strong", "Create chain"
    assert_select "a.btn--block", /Meet about it/
  end

  test "new task is prefilled from the topic" do
    get new_project_topic_task_path(@project, @topic)
    assert_response :success
    assert_select "input[name='task[title]'][value=?]", @topic.title
    assert_select "textarea", /401s exactly 24h/
    assert_select "input[type=checkbox][name='task[bug]'][checked]" # issues default to bugs
  end

  test "creating a task links it to the topic and approves the topic" do
    label = @project.labels.create!(name: "Backend")
    assert_difference "@project.tasks.count", 1 do
      post project_topic_tasks_path(@project, @topic), params: { task: {
        title: "Fix expiry", description: "Details", assignee_id: users(:jonas).id, estimate_days: "3", due_on: "2026-10-19",
        sprint_id: sprints(:sprint_14).id, bug: "1", label_ids: [ "", label.id ]
      } }
    end

    task = @project.tasks.find_by!(title: "Fix expiry")
    assert_redirected_to project_topic_path(@project, @topic)
    assert_equal 1440, task.estimate_minutes
    assert_equal 3.0, task.estimate_days
    assert_equal [ label ], task.labels.to_a
    assert_equal users(:ines), task.creator
    assert_equal @topic, task.topic
    assert task.bug?
    assert @topic.reload.approved?
  end

  test "creating a task ignores assignees and sprints from elsewhere" do
    outsider = User.create!(name: "Out Sider", email: "out@elsewhere.io")
    post project_topic_tasks_path(@project, @topic), params: { task: { title: "Hmm", assignee_id: outsider.id } }
    assert_nil @project.tasks.find_by!(title: "Hmm").assignee
  end

  test "a task needs a title" do
    assert_no_difference "Task.count" do
      post project_topic_tasks_path(@project, @topic), params: { task: { title: "" } }
    end
    assert_response :unprocessable_content
  end

  test "creating a chain makes ordered steps and approves the topic" do
    assert_difference [ "Chain.count" ], 1 do
      post project_topic_chains_path(@project, @topic), params: { chain: {
        title: "Fix expiry", sprint_id: sprints(:sprint_14).id,
        steps: {
          "0" => { title: "Backend", description: "Limits", assignee_id: users(:jonas).id, estimate_days: "3" },
          "1" => { title: "Dashboard", description: "Banner", assignee_id: "", estimate_days: "2" },
          "2" => { title: "", description: "ignored" }
        }
      } }
    end

    chain = Chain.find_by!(title: "Fix expiry")
    assert_redirected_to project_topic_path(@project, @topic)
    assert_equal %w[Backend Dashboard], chain.tasks.map(&:title)
    assert_equal [ 1, 2 ], chain.tasks.map(&:chain_position)
    assert_equal sprints(:sprint_14), chain.tasks.first.sprint
    assert @topic.reload.approved?
  end

  test "a chain without steps is rejected and nothing is saved" do
    assert_no_difference [ "Chain.count", "Task.count" ] do
      post project_topic_chains_path(@project, @topic), params: { chain: { title: "Empty", steps: { "0" => { title: "" } } } }
    end
    assert_response :unprocessable_content
    assert_match(/at least one step/i, flash[:alert])
  end

  test "the meeting form suggests slots and lists the people in the topic first" do
    @topic.messages.create!(author: users(:jonas), body: "Reproduced")
    get new_project_topic_meeting_path(@project, @topic)

    assert_response :success
    assert_select "select[name=starts_at] option", 5
    assert_select ".invitee", 2
    assert_select ".hours__bar", 2
  end

  test "creating a meeting provisions the call, invites people and posts the link" do
    Setting.current.update!(meeting_provider: "zoom")
    IntegrationConnection.create!(provider: "zoom", external_account: "ops@orbitlabs.dev", connected_by: users(:ines),
                                                       access_token: "tok", expires_at: 1.hour.from_now)
    stub_request(:post, "https://api.zoom.us/v2/users/me/meetings")
      .to_return(status: 201, body: { id: 42, join_url: "https://zoom.us/j/42" }.to_json, headers: JSON_HEADERS)
    starts_at = 2.days.from_now.change(min: 0).utc.iso8601

    assert_difference "@topic.meetings.count", 1 do
      post project_topic_meetings_path(@project, @topic), params: {
        starts_at: starts_at, duration_minutes: "45", transcribe: "1",
        attendees: { users(:jonas).id.to_s => { invite: "1", requirement: "optional" }, users(:ines).id.to_s => { invite: "0", requirement: "required" } }
      }
    end

    meeting = @topic.meetings.last
    assert_redirected_to project_topic_path(@project, @topic)
    assert_equal "https://zoom.us/j/42", meeting.join_url
    assert_equal 45, meeting.duration_minutes
    assert_equal({ users(:jonas).id => "optional" }, meeting.participants.pluck(:user_id, :requirement).to_h)
    assert_includes @topic.messages.last.body, "https://zoom.us/j/42"
  end

  test "creating a meeting without a connected tool explains what to do" do
    Setting.current.update!(meeting_provider: "zoom")
    assert_no_difference "Meeting.count" do
      post project_topic_meetings_path(@project, @topic), params: { starts_at: 2.days.from_now.utc.iso8601, duration_minutes: "30" }
    end
    assert_redirected_to new_project_topic_meeting_path(@project, @topic)
    assert_match(/connect a meeting tool/i, flash[:alert])
  end

  test "creating a meeting with no tool chosen at all is refused" do
    assert_no_difference "Meeting.count" do
      post project_topic_meetings_path(@project, @topic), params: { starts_at: 2.days.from_now.utc.iso8601, duration_minutes: "30" }
    end
    assert_redirected_to new_project_topic_meeting_path(@project, @topic)
  end
end

class TopicAiDraftTest < ActionDispatch::IntegrationTest
  include LlmHelper
  JSON_HEADERS = { "Content-Type" => "application/json" }.freeze

  setup do
    @project = projects(:apollo)
    @topic = topics(:refresh_tokens)
    sign_in_as users(:ines)
  end

  def stub_gemini(json)
    stub_request(:post, %r{generativelanguage.googleapis.com}).to_return(status: 200, headers: JSON_HEADERS,
      body: { candidates: [ { content: { parts: [ { text: json.to_json } ] } } ] }.to_json)
  end

  test "without a provider the pages offer no AI button" do
    get new_project_topic_task_path(@project, @topic)
    assert_select ".ai-draft", count: 0
  end

  test "with a provider the task page offers a draft button" do
    with_llm("gemini") do
      get new_project_topic_task_path(@project, @topic)
      assert_select ".ai-draft a", /Draft with AI/
    end
  end

  test "drafting fills the task form and offers another draft" do
    stub_gemini(title: "Fix silent refresh-token expiry", description: "What we agreed\n- Sliding window")
    with_llm("gemini") do
      get new_project_topic_task_path(@project, @topic, draft: 1)

      assert_select "input[name='task[title]'][value=?]", "Fix silent refresh-token expiry"
      assert_select "textarea", /Sliding window/
      assert_select ".tag--draft", /Drafted from/
      assert_select ".ai-draft a", /Try another draft/
    end
  end

  test "drafting a chain fills the steps" do
    stub_gemini(title: "Fix expiry", steps: [ { title: "Backend", description: "Limits", days: 3 }, { title: "QA", description: "Soak", days: 1 } ])
    with_llm("gemini") do
      get new_project_topic_chain_path(@project, @topic, draft: 1)

      assert_select ".steps-editor .step-card", 2
      assert_select "input[name='chain[steps][0][title]'][value=Backend]"
      assert_select "input[name='chain[steps][1][estimate_days]'][value='1.0']"
    end
  end

  test "a failing provider keeps the page usable with a message" do
    stub_request(:post, %r{generativelanguage}).to_return(status: 500, body: "{}", headers: JSON_HEADERS)
    with_llm("gemini") do
      get new_project_topic_task_path(@project, @topic, draft: 1)
      assert_response :success
      assert_select "input[name='task[title]'][value=?]", @topic.title
      assert_select ".toast--alert", /AI draft failed/
    end
  end

  test "asking for a draft while AI is off explains how to enable it" do
    get new_project_topic_task_path(@project, @topic, draft: 1)
    assert_response :success
    assert_select ".toast--alert", /LLM_ENABLED/
  end
end
