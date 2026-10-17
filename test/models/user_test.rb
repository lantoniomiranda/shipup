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

  test "reports the role in a workspace" do
    assert_equal "admin", users(:ines).role_in(workspaces(:orbit))
  end
end
