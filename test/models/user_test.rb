require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "builds initials, first name and city" do
    ines = users(:ines)
    assert_equal "IM", ines.initials
    assert_equal "Inês", ines.first_name
    assert_equal "Lisbon", ines.city
  end

  test "normalizes email and creates default preferences" do
    user = User.create!(name: "Sofia Reyes", email: "  Sofia@Orbitlabs.DEV ")
    assert_equal "sofia@orbitlabs.dev", user.email
    assert_equal "paper", user.preference.theme_bg
  end

  test "email is unique regardless of case" do
    assert_not User.new(name: "Dupe", email: "INES@orbitlabs.dev").valid?
  end

  test "admins see every teammate, everyone else only the people on their projects" do
    outsider = User.create!(name: "Out Sider", email: "out@elsewhere.io")
    assert_includes users(:ines).teammates, outsider
    assert_includes users(:jonas).teammates, users(:ines)
    assert_not_includes users(:jonas).teammates, outsider
  end

  test "admins and project admins can approve time off" do
    assert users(:ines).approver?
    assert_not users(:jonas).approver?
    projects(:apollo).project_memberships.find_by!(user: users(:jonas)).admin!
    assert users(:jonas).approver?
  end
end
