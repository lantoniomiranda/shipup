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

  test "the meeting form has a calendar date, a time and suggested times" do
    get new_project_topic_meeting_path(@project, @topic)

    assert_select "input[type=date][name=date][min=?]", Date.current.iso8601
    assert_select "input[type=time][name=time][step='300']"
    assert_select ".chips .chip", 5
    assert_select ".chip[data-meeting-form-date-param][data-meeting-form-time-param]"
    assert_select "[data-meeting-form-zone-value=?]", users(:ines).time_zone
    assert_select ".meeting-when", /Europe\/Lisbon/
    assert_select "select[name=starts_at]", count: 0
  end

  test "the default date and time are the best suggested slot in the organizer's zone" do
    get new_project_topic_meeting_path(@project, @topic)
    first_chip = css_select(".chips .chip").first
    assert_equal first_chip["data-meeting-form-date-param"], css_select("input[name=date]").first["value"]
    assert_equal first_chip["data-meeting-form-time-param"], css_select("input[name=time]").first["value"]
  end

  test "the meeting form suggests slots and lists the people in the topic first" do
    @topic.messages.create!(author: users(:jonas), body: "Reproduced")
    get new_project_topic_meeting_path(@project, @topic)

    assert_response :success
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
      assert_select ".ai-draft__error", /AI draft failed: gemini error \(500\)/
    end
  end

  test "asking for a draft while AI is off explains how to enable it" do
    get new_project_topic_task_path(@project, @topic, draft: 1)
    assert_response :success
    assert_select ".toast--alert", /LLM_ENABLED/
  end
end

class MeetingSchedulingTest < ActionDispatch::IntegrationTest
  JSON_HEADERS = { "Content-Type" => "application/json" }.freeze

  setup do
    @project = projects(:apollo)
    @topic = topics(:refresh_tokens)
    Setting.current.update!(meeting_provider: "zoom")
    IntegrationConnection.create!(provider: "zoom", external_account: "ops@orbitlabs.dev", connected_by: users(:ines), access_token: "tok", expires_at: 1.hour.from_now)
    @zoom = stub_request(:post, "https://api.zoom.us/v2/users/me/meetings").to_return(status: 201, body: { id: 7, join_url: "https://zoom.us/j/7" }.to_json, headers: JSON_HEADERS)
    sign_in_as users(:ines) # Europe/Lisbon
    travel_to Time.utc(2026, 10, 20, 9)
  end

  teardown { travel_back }

  def schedule(**params)
    post project_topic_meetings_path(@project, @topic), params: { duration_minutes: "30", transcribe: "1" }.merge(params)
  end

  test "any date and time can be picked and are read in the organizer's own zone" do
    assert_difference "@topic.meetings.count", 1 do
      schedule(date: "2026-10-22", time: "14:30")
    end

    assert_redirected_to project_topic_path(@project, @topic)
    # Lisbon is UTC+1 on 22 Oct 2026 (summer time), so 14:30 there is 13:30 UTC.
    assert_equal Time.utc(2026, 10, 22, 13, 30), @topic.meetings.last.starts_at
    assert_requested @zoom
  end

  test "winter dates use winter offsets" do
    schedule(date: "2026-12-10", time: "09:00")
    assert_equal Time.utc(2026, 12, 10, 9, 0), @topic.meetings.last.starts_at # Lisbon is UTC+0 in December
  end

  test "someone in another zone schedules in theirs" do
    users(:ines).update!(time_zone: "Asia/Tokyo", time_zone_set_by_user: true)
    schedule(date: "2026-10-22", time: "14:30")
    assert_equal Time.utc(2026, 10, 22, 5, 30), @topic.meetings.last.starts_at
  end

  test "a time in the past is refused with a clear message" do
    assert_no_difference "Meeting.count" do
      schedule(date: "2026-10-19", time: "10:00")
    end
    assert_redirected_to new_project_topic_meeting_path(@project, @topic)
    assert_match(/in the future/, flash[:alert])
    assert_not_requested @zoom
  end

  test "an unreadable date is refused" do
    assert_no_difference "Meeting.count" do
      schedule(date: "not-a-date", time: "xx")
    end
    assert_match(/Check the time/, flash[:alert])
  end

  test "a missing time defaults to the start of the working day instead of failing" do
    schedule(date: "2026-10-22", time: "")
    assert_equal Time.utc(2026, 10, 22, 8, 0), @topic.meetings.last.starts_at # 09:00 Lisbon
  end

  test "the ISO8601 form still works for scripts" do
    schedule(starts_at: "2026-10-22T13:30:00Z")
    assert_equal Time.utc(2026, 10, 22, 13, 30), @topic.meetings.last.starts_at
  end

  test "the invitee rows carry the data the browser needs to flag working hours" do
    users(:jonas).preference.update!(work_day_start: "08:00", work_day_end: "16:00")
    get new_project_topic_meeting_path(@project, @topic)

    row = css_select(".invitee").find { |li| li.text.include?("Jonas K.") }
    assert_equal "Europe/Berlin", row["data-zone"]
    assert_equal "480", row["data-work-start"]
    assert_equal "960", row["data-work-end"]
  end
end
