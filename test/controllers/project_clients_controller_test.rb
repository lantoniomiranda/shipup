require "test_helper"

class ProjectClientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:apollo)
    @northwind = Client.create!(name: "Northwind")
    @northwind.contacts.create!(name: "Priya Nair", email: "priya@northwind.io")
    @northwind.contacts.create!(name: "Tom", email: "tom@northwind.io")
    @project.project_clients.create!(client: @northwind, status: "active")
    @hooli = Client.create!(name: "Hooli")
    @hooli.contacts.create!(name: "Dana Whitfield", email: "dana@hooli.dev")
    @project.project_clients.create!(client: @hooli)
    sign_in_as users(:ines)
  end

  test "lists clients with contacts, topic counts and status" do
    @project.topics.create!(author: users(:ines), title: "From Northwind", client: @northwind)
    get project_clients_path(@project)

    assert_response :success
    assert_select "tbody tr", 2
    assert_select "tr", text: /Northwind.*Priya Nair.*\+1 contact.*1 topic.*Active/m
    assert_select "tr", text: /Hooli.*0 topics.*No topics yet.*Invite pending/m
    assert_select ".tab--active", /Clients/
  end

  test "filters by status and shows counts" do
    get project_clients_path(@project, filter: "invite_pending")
    assert_select "tbody tr", 1
    assert_select ".segmented__item", /All 2/
    assert_select ".segmented__item--active", /Invite pending 1/
  end

  test "adds a client with several emails and invites it to the project" do
    assert_difference [ "Client.count", "ProjectClient.count" ], 1 do
      post project_clients_path(@project), params: { company: "Contoso", contact_name: "Elena Rossi", emails: [ "elena@contoso.eu", "ops@contoso.eu", "ELENA@contoso.eu" ] }
    end

    client = Client.find_by!(name: "Contoso")
    assert_redirected_to project_clients_path(@project)
    assert_equal %w[elena@contoso.eu ops@contoso.eu], client.contacts.order(:email).pluck(:email)
    assert @project.project_clients.find_by!(client: client).invite_pending?
  end

  test "reuses an existing client by name instead of duplicating it" do
    assert_no_difference "Client.count" do
      post project_clients_path(@project), params: { company: "Hooli", contact_name: "Dana", emails: [ "new@hooli.dev" ] }
    end
    assert_includes @hooli.contacts.pluck(:email), "new@hooli.dev"
  end

  test "requires at least one email" do
    assert_no_difference "Client.count" do
      post project_clients_path(@project), params: { company: "Initech", contact_name: "Bill", emails: [] }
    end
    assert_response :unprocessable_content
  end

  test "the add form lists the project's clients" do
    get new_project_client_path(@project)
    assert_select ".client-list li", 2
    assert_select "input[name=company]"
    assert_select "[data-controller=tags]"
  end
end
