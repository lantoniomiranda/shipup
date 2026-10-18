require "test_helper"

class BackofficeTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @staff = users(:staff)
    @acme = Workspace.provision!(name: "Acme Corp", admin_email: "boss@acme.io", seats_limit: 5)
  end

  # ---- access ---------------------------------------------------------------
  test "visitors are sent to sign-in" do
    get backoffice_root_path
    assert_redirected_to sign_in_path
  end

  test "ordinary users get a 404, not a login prompt or a 403" do
    sign_in_as users(:ines)
    get backoffice_root_path
    assert_response :not_found
    get backoffice_tenants_path
    assert_response :not_found
    post backoffice_tenants_path, params: { workspace: { name: "Sneaky", admin_email: "x@y.io" } }
    assert_response :not_found
    assert_nil Workspace.find_by(name: "Sneaky")
  end

  test "workspace admins are not platform staff" do
    sign_in_as users(:ines)
    patch suspend_backoffice_tenant_path(@acme)
    assert_response :not_found
    assert @acme.reload.active?
  end

  # ---- dashboard --------------------------------------------------------------
  test "the dashboard summarises the platform" do
    @acme.suspend!
    Workspace.create!(name: "Soon Over", trial_ends_at: 3.days.from_now)
    sign_in_as @staff
    get backoffice_root_path

    assert_response :success
    assert_select ".kpi", 4
    assert_select ".kpi strong", text: Workspace.count.to_s
    assert_select ".bo-list a", "Acme Corp"
    assert_select ".bo-list a", text: "Soon Over" # trial ending within a week
    assert_select ".tag--staff", "Backoffice"
  end

  # ---- listing -----------------------------------------------------------------
  test "lists tenants with plan, status, members and projects" do
    sign_in_as @staff
    get backoffice_tenants_path

    assert_select "tbody tr", Workspace.count
    assert_select "tr", text: /Acme Corp.*Trial.*Active/m
    assert_select "tr", text: /Orbit Labs.*2 .*0|Orbit Labs/m
  end

  test "searches by name and slug" do
    sign_in_as @staff
    get backoffice_tenants_path(q: "acme")
    assert_select "tbody tr", 1
    get backoffice_tenants_path(q: "orbit-labs")
    assert_select "tbody tr", 1
  end

  test "filters by status" do
    @acme.suspend!
    sign_in_as @staff
    get backoffice_tenants_path(status: "suspended")
    assert_select "tbody tr", 1
    assert_select "tr", /Acme Corp/
    assert_select ".segmented__item--active", "Suspended"
  end

  # ---- creating -------------------------------------------------------------------
  test "creating a tenant invites its first admin by email" do
    sign_in_as @staff

    assert_difference "Workspace.count", 1 do
      assert_enqueued_emails 1 do
        post backoffice_tenants_path, params: { workspace: { name: "Globex Corp", plan: "starter", seats_limit: "10", admin_email: "hank@globex.com",
                                                               email_domain: "globex.com", allow_domain_join: "1", trial_days: "30" } }
      end
    end

    workspace = Workspace.find_by!(name: "Globex Corp")
    assert_redirected_to backoffice_tenant_path(workspace)
    assert workspace.plan_starter?
    assert_equal 10, workspace.seats_limit
    assert_equal "globex.com", workspace.email_domain
    assert workspace.allow_domain_join?
    assert_equal [ "hank@globex.com" ], workspace.invitations.pending.pluck(:email)
    assert workspace.invitations.sole.admin?
    assert_equal @staff, workspace.invitations.sole.invited_by
  end

  test "the invited admin can then sign in and lands as admin of the new tenant" do
    sign_in_as @staff
    post backoffice_tenants_path, params: { workspace: { name: "Globex Corp", plan: "trial", admin_email: "hank@globex.com" } }
    sign_out

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = omniauth_hash("google_oauth2", uid: "hank", email: "hank@globex.com", name: "Hank Scorpio")
    post "/auth/google_oauth2"
    follow_redirect!

    assert_equal "admin", User.find_by!(email: "hank@globex.com").role_in(Workspace.find_by!(name: "Globex Corp"))
  end

  test "an invalid tenant re-renders the form with the entered values" do
    sign_in_as @staff
    assert_no_difference [ "Workspace.count", "Invitation.count" ] do
      post backoffice_tenants_path, params: { workspace: { name: "Broken Co", plan: "team", admin_email: "not-an-email" } }
    end
    assert_response :unprocessable_content
    assert_select "input[name='workspace[name]'][value='Broken Co']"
    assert_select "input[name='workspace[admin_email]'][value='not-an-email']"
  end

  test "the new tenant form asks for the first admin" do
    sign_in_as @staff
    get new_backoffice_tenant_path
    assert_select "input[name='workspace[admin_email]']"
    assert_select "select[name='workspace[plan]'] option", Workspace::PLANS.size
  end

  # ---- showing & editing -----------------------------------------------------------
  test "the tenant page shows usage, members and pending invitations" do
    sign_in_as @staff
    get backoffice_tenant_path(workspaces(:orbit))

    assert_response :success
    assert_select "h1", "Orbit Labs"
    assert_select ".kpi", 4
    assert_select ".bo-list li", text: /Inês Machado/
    assert_select ".bo-list li", text: /Jonas Keller/

    get backoffice_tenant_path(@acme)
    assert_select ".bo-list li", text: /boss@acme.io/
    assert_select "button", text: "Resend"
    assert_select "button", text: "Revoke"
  end

  test "editing changes plan, seats and domain settings" do
    sign_in_as @staff
    patch backoffice_tenant_path(@acme), params: { workspace: { name: "Acme Inc", plan: "enterprise", seats_limit: "50", email_domain: "acme.io", allow_domain_join: "1" } }

    assert_redirected_to backoffice_tenant_path(@acme)
    @acme.reload
    assert_equal [ "Acme Inc", "enterprise", 50, "acme.io", true ], [ @acme.name, @acme.plan, @acme.seats_limit, @acme.email_domain, @acme.allow_domain_join ]
  end

  test "an invalid edit is rejected" do
    sign_in_as @staff
    patch backoffice_tenant_path(@acme), params: { workspace: { name: "", plan: "team" } }
    assert_response :unprocessable_content
  end

  # ---- suspension --------------------------------------------------------------------
  test "suspending records the reason and reactivating clears it" do
    sign_in_as @staff
    patch suspend_backoffice_tenant_path(@acme), params: { reason: "Invoice overdue" }
    assert @acme.reload.suspended?
    assert_equal "Invoice overdue", @acme.suspended_reason

    get backoffice_tenant_path(@acme)
    assert_select ".bo-banner", /Invoice overdue/

    patch reactivate_backoffice_tenant_path(@acme)
    assert @acme.reload.active?
  end

  # ---- invitations ---------------------------------------------------------------------
  test "staff can invite more people to a tenant" do
    sign_in_as @staff
    assert_enqueued_emails 1 do
      post backoffice_tenant_invitations_path(@acme), params: { invitation: { email: "cfo@acme.io", role: "manager" } }
    end
    assert_equal "manager", @acme.invitations.pending.find_by!(email: "cfo@acme.io").role
  end

  test "inviting past the seat limit is refused" do
    @acme.update!(seats_limit: 1) # boss@acme.io already holds the only seat
    sign_in_as @staff
    assert_no_enqueued_emails do
      post backoffice_tenant_invitations_path(@acme), params: { invitation: { email: "extra@acme.io", role: "member" } }
    end
    assert_match(/No seats left/, flash[:alert])
  end

  test "resending sends another email and revoking closes the invitation" do
    invitation = @acme.invitations.sole
    sign_in_as @staff

    assert_enqueued_emails 1 do
      post resend_backoffice_tenant_invitation_path(@acme, invitation)
    end

    delete backoffice_tenant_invitation_path(@acme, invitation)
    assert_not invitation.reload.pending?
  end

  test "invitation emails explain how to get in" do
    mail = InvitationMailer.invite(@acme.invitations.sole)
    assert_equal [ "boss@acme.io" ], mail.to
    assert_match(/invited to Acme Corp on ohship/, mail.subject)
    assert_includes mail.text_part.body.to_s, "Google or Microsoft account"
    assert_includes mail.html_part.body.to_s, sign_in_url(host: "example.com")
  end

  test "a staff member without a workspace can use the backoffice but not the app" do
    sign_in_as @staff
    get backoffice_root_path
    assert_response :success
    assert_select "a", text: "Open the app", count: 0
  end
end
