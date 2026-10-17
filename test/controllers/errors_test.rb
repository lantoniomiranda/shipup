require "test_helper"

class ErrorsTest < ActionDispatch::IntegrationTest
  # The test env shows Rails' debug pages; production shows ours, so turn detailed exceptions off here.
  setup { @detailed = Rails.application.env_config["action_dispatch.show_detailed_exceptions"]; Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false }
  teardown { Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @detailed }

  test "unknown paths render the branded 404 page" do
    sign_in_as users(:ines)
    get "/nope/never"
    assert_response :not_found
    assert_select "h1", "We can't find that page"
    assert_select ".eyebrow", "Error 404"
    assert_select "a", /Back to your projects/
  end

  test "visitors on an error page are pointed at sign-in" do
    get "/nope"
    assert_response :not_found
    assert_select "a", /Go to sign in/
  end

  test "every supported code has its own message" do
    { 400 => "That request didn&#39;t make sense", 403 => "You don&#39;t have access to this", 406 => "Your browser is too old",
      422 => "That change was rejected", 500 => "Something went wrong on our side" }.each do |code, title|
      html = ErrorsController.render("errors/show", locals: { code: code }, layout: "application")
      assert_includes html, title
      assert_includes html, "Error #{code}"
    end
  end

  test "records that do not exist are a branded 404" do
    sign_in_as users(:ines)
    get project_topic_path(projects(:apollo), 0)
    assert_response :not_found
    assert_select "h1", "We can't find that page"
  end

  test "forbidden actions show the 403 page" do
    sign_in_as users(:jonas)
    get integrations_path
    assert_response :forbidden
    assert_select "h1", "You don't have access to this"
  end

  test "errors carry the product name in the title" do
    get "/nope"
    assert_select "title", /404 .* ShipUp/
  end

  test "static fallbacks are branded and self-contained" do
    %w[400 404 406-unsupported-browser 422 500].each do |name|
      html = File.read(Rails.root.join("public/#{name}.html"))
      assert_includes html, "ShipUp"
      assert_not_includes html, "<link", "#{name}.html must not depend on other assets"
    end
  end
end
