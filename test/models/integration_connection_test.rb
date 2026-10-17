require "test_helper"

class IntegrationConnectionTest < ActiveSupport::TestCase
  setup do
    @connection = workspaces(:orbit).integration_connections.create!(
      provider: "github", external_account: "orbitlabs", connected_by: users(:ines),
      access_token: "gho_secret", expires_at: 1.hour.from_now
    )
  end

  test "tokens are encrypted at rest" do
    raw = IntegrationConnection.connection.select_value("SELECT access_token FROM integration_connections WHERE id = #{@connection.id}")
    assert_not_equal "gho_secret", raw
    assert_equal "gho_secret", @connection.reload.access_token
  end

  test "knows when it has expired" do
    assert_not @connection.expired?
    assert @connection.expired?(now: 2.hours.from_now)
  end

  test "one connection per provider per workspace" do
    dupe = workspaces(:orbit).integration_connections.build(provider: "github", external_account: "x", connected_by: users(:ines))
    assert_not dupe.valid?
  end
end
