require "test_helper"

class NewProjectTest < ActionDispatch::IntegrationTest
  test "admins can create a project and become its manager" do
    sign_in_as users(:ines)

    assert_difference "workspaces(:orbit).projects.count", 1 do
      post projects_path, params: { project: { name: "Atlas Mobile", key: "atl", description: "Field app", color: "teal", icon: "smartphone" } }
    end

    project = workspaces(:orbit).projects.find_by!(key: "ATL")
    assert_redirected_to project_topics_path(project)
    assert_equal "teal", project.color
    assert_equal "manager", project.project_memberships.find_by!(user: users(:ines)).role
  end

  test "a key is derived from the name when left blank" do
    sign_in_as users(:ines)
    post projects_path, params: { project: { name: "Billing Core", key: "", color: "blue", icon: "receipt" } }
    assert workspaces(:orbit).projects.exists?(key: "BIL")
  end

  test "invalid projects re-render the form" do
    sign_in_as users(:ines)
    assert_no_difference "Project.count" do
      post projects_path, params: { project: { name: "", key: "APO", color: "teal", icon: "rocket" } }
    end
    assert_response :unprocessable_content
  end

  test "members cannot see or use the form" do
    sign_in_as users(:jonas)
    get new_project_path
    assert_response :forbidden
    assert_no_difference "Project.count" do
      post projects_path, params: { project: { name: "Nope", key: "NOP" } }
    end
    assert_response :forbidden
  end

  test "the home page links to the form for admins" do
    sign_in_as users(:ines)
    get root_path
    assert_select "a.btn--primary[href=?]", new_project_path
    get new_project_path
    assert_response :success
    assert_select ".swatch", 5
    assert_select ".avatar-option", Project::ICONS.size
  end
end
