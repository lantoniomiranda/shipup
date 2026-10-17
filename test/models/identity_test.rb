require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  test "a provider account links to only one user" do
    attrs = { provider: "google", uid: "123", email: "a@b.co" }
    users(:ines).identities.create!(attrs)
    assert_not users(:jonas).identities.build(attrs).valid?
  end

  test "only google and microsoft are accepted" do
    assert_not users(:ines).identities.build(provider: "github", uid: "1", email: "a@b.co").valid?
  end
end
