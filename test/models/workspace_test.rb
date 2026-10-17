require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  test "derives a slug from the name" do
    assert_equal "acme-corp", Workspace.create!(name: "Acme Corp").slug
  end

  test "rejects an unknown meeting provider" do
    workspace = workspaces(:orbit)
    workspace.meeting_provider = "skype"
    assert_not workspace.valid?
  end

  test "finds the connection for a provider" do
    connection = workspaces(:orbit).integration_connections.create!(
      provider: "zoom", external_account: "ops@orbitlabs.dev", connected_by: users(:ines)
    )
    assert_equal connection, workspaces(:orbit).connection_for("zoom")
    assert_nil workspaces(:orbit).connection_for("github")
  end
end
