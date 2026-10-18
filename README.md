# Shipup

Rails 8 app (product name **ohship**): project management built around **topics** (conversations),
**tasks and chains** (the work), **meetings**, a sprint **board**, clients and team time off.
The UI is replicated from `design-draft-claude-1.pen`.

## Changelog

Keep this section current: every change set adds a line here (newest first).

- Renamed the product to **ohship** and added the rocket logo (CSS-masked so it follows the theme colours) and a new favicon.
- `Taskfile.yml`: `task start | stop | restart | status | logs` manage the server and Postgres.
- **Multi-tenant SaaS**: a workspace is a tenant with a status (active/suspended), plan (trial/starter/team/enterprise), trial end and seat limit. Sign-up is **invite-only**: unknown emails are refused unless they hold a pending `Invitation`, belong to a workspace that enabled company-domain joining, or are platform staff listed in `PLATFORM_ADMIN_EMAILS`. Signing in consumes invitations (a person can belong to several tenants). `Workspace.provision!` creates a tenant and invites its first admin.
- **Tenant side of the SaaS**: workspace switcher in the top bar (session-based, only your own tenants), a *People* page for workspace admins (invite by email, change roles, remove people, resend/revoke invitations; the last admin can't be demoted or removed; seat limits enforced), a branded "workspace suspended" page, a "no workspace yet" page, and a trial banner for admins. `test/controllers/tenant_isolation_test.rb` pins that one tenant can never read or write another's data.
- **Backoffice** (`/backoffice`, platform staff only; everyone else gets a 404): tenants overview, tenant list with search and status filter, onboarding (creates the workspace and emails its first admin), editing plan/seats/domain rules, suspend/reactivate with a reason, and invitation management (invite, resend, revoke). Invitation mail goes through `InvitationMailer` (set `SMTP_*`, `MAIL_FROM`, `APP_HOST` in production). Locally: `/dev/sign_in?email=staff@shipup.dev&to=/backoffice`.
- **Task chat** (design's right-hand "Chat" on a task) with direct replies (quoted), editing (author only, shows "edited") and removal (author, workspace admins, project managers; soft delete so replies keep their quote). Topic threads got the same abilities through the shared `ChatMessage` concern and `messages/_message` partials.
- **LLM adapter**: pick a provider with `LLM_ENABLED=claude|gemini|grok|gpt` and `LLM_API_KEY` (optional `LLM_MODEL`, `LLM_BASE_URL`). `Llm.client.complete(prompt, system:, json:)` is the only API the app uses, so switching provider is configuration. First feature: *Draft with AI* / *Try another draft* on the create task and create chain pages (`Llm::Drafts`). Unset = AI features hidden. Add a provider by subclassing `Llm::Base`.
- Keyboard shortcuts rebuilt: one global handler (`hotkeys_controller.js`) driven by `data-hotkey` attributes and one registry, `config/keybindings.yml`, which also feeds the **?** help dialog. Navigation uses `g` chords (`g b` board, `g t` topics, `g h` projects…); primary actions use **Ctrl/Cmd+Enter**; no browser-owned combos (Ctrl+S, Space…). Project tabs now show the shortcuts of the *other* tabs, not the current one. `node script/check_keys.mjs` presses the real keys in a browser.
- Sprints have a state (planned, active, completed) with a unique-index guarantee of **one active sprint per project**. Create a sprint from the backlog (*Plan sprint*), start it (carrying unfinished tasks over if you like) and it shows on the board immediately; *Complete sprint* sits on the board. Workspace admins and project managers manage sprints.
- Branded error pages (400, 403, 404, 406, 422, 500) rendered by `ErrorsController` via `config.exceptions_app`; static `public/*.html` fallbacks restyled. Forbidden actions render the 403 page.
- Fix: project cards on the dashboard now open the project. Product renamed from Nook to **ohship**.

## Stack

Rails 8.1 · PostgreSQL · Hotwire (Turbo + Stimulus) · importmap · Propshaft (plain CSS + design
tokens) · Solid Queue/Cache/Cable · Minitest + WebMock · Kamal.

## Getting started

```sh
bin/setup        # copies .env, starts Postgres (docker compose), prepares the DB, runs the server
bin/rails db:seed  # demo workspace from the design (Orbit Labs, Apollo Gateway, …)
```

Postgres listens on `localhost:5433` (see `docker-compose.yml`, overridable in `.env`).
Without OAuth credentials, sign in locally through `http://localhost:3000/dev/sign_in?email=ines@orbitlabs.dev`
(development only).

## Everyday commands

With [go-task](https://taskfile.dev) (`brew install go-task`):

```sh
task start      # Postgres + Rails server in the background (http://localhost:3000)
task stop       # stop the server and Postgres
task restart    # restart only the server
task status     # what is running
task logs       # follow the Rails log
task            # list everything (db:seed, console, test, ci…)
```

Or directly:

```sh
bin/dev                                   # run the server
bin/rails test                            # unit + integration tests
bin/rails test test/models/x_test.rb:12   # a single test
bin/rubocop                               # lint
bin/ci                                    # everything CI runs
node script/check_keys.mjs                # browser smoke test of keyboard shortcuts (needs the server running)
```

## Sign-in and integrations

Google and Microsoft OAuth are the only ways in (no passwords). Workspace admins connect **Zoom**,
**Google Meet** and **GitHub** under *Integrations* (`/integrations`). Credentials live in `.env`
(see `.env.example`):

| Feature | Variables | Redirect URI |
| --- | --- | --- |
| Sign in with Google | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | `/auth/google_oauth2/callback` |
| Sign in with Microsoft | `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET`, `MICROSOFT_TENANT_ID` | `/auth/entra_id/callback` |
| Zoom meetings | `ZOOM_CLIENT_ID`, `ZOOM_CLIENT_SECRET` | `/integrations/zoom/callback` |
| Google Meet links | reuses the Google client (add the Calendar scope) | `/integrations/google_meet/callback` |
| Platform staff (backoffice) | `PLATFORM_ADMIN_EMAILS` (comma separated) | – |
| AI drafts | `LLM_ENABLED` (`claude`/`gemini`/`grok`/`gpt`), `LLM_API_KEY`, optional `LLM_MODEL`, `LLM_BASE_URL` | – |
| GitHub | `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `GITHUB_WEBHOOK_SECRET` | `/integrations/github/callback` |

GitHub pull requests that mention a task key (e.g. `APO-97`) in their title, branch or description
are attached to that task through the signed webhook at `/webhooks/github`.
Production also needs `AR_ENCRYPTION_PRIMARY_KEY`, `AR_ENCRYPTION_DETERMINISTIC_KEY` and
`AR_ENCRYPTION_KEY_DERIVATION_SALT` (`bin/rails db:encryption:init`) to encrypt stored tokens.

## Theming

`app/assets/stylesheets/tokens.css` holds the design tokens. Backgrounds (`paper`, `mist`, `sage`,
`night`) and accents (`orange`, `blue`, `teal`, `plum`, `mustard`) are switched with `data-bg` /
`data-accent` on `<html>`; users pick theirs under *Account → Appearance*.

## What is built

Sign in · workspace setup (meeting tool, GitHub) · projects home and new project · topics (list,
thread, new with similar-topic suggestions, voting) · Move on → create task / chain · meet about it
(Zoom / Google Meet) · backlog and sprint planning · sprint board (drag and drop, keyboard) · task
page with time tracker · timeline (with `.ics` export) · clients · analytics · account · appearance ·
time off.
Quick search ("Super Space": `/` or Ctrl/Cmd+Space) covers topics, tasks and projects.
Not built yet from the design: rediscussion analytics, undo toast
and Microsoft Teams meetings.
