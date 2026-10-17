require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "the app boots and reports healthy" do
    get rails_health_check_path
    assert_response :success
  end
end
