---
name: shipup
description: Codebase guide for the shipup Rails 8.1 app. Use when working in this repository to build, lint, test, or understand the stack (Hotwire, importmap, PostgreSQL, Solid Queue/Cache/Cable, Kamal).
---

# shipup

## Working with other agents (read first)

Several agents may edit this repo at the same time. To keep out of each other's way:

- Before starting, run `git status`, `git log --oneline -5` and `git worktree list`. Uncommitted changes or migrations you didn't write belong to someone else: don't commit, revert or "fix" them.
- If another agent is changing the schema or core models, work in your own **git worktree** (`git worktree add ../shipup-<name> -b <name>/<topic>`) with your own databases (`DB_SUFFIX=_<name>` in that worktree's `.env`, read by `config/database.yml`) and your own port. Never run `db:migrate`/`db:reset` in a tree whose pending migrations aren't yours.
- Commit only your own paths (`git add <paths>`, never `git add -A` in a shared tree) with focused messages; rebase or merge onto the main branch before handing over and resolve conflicts, don't overwrite.
- Update this file in small, additive bullets under the right section (append, don't rewrite or reorder), so concurrent edits merge cleanly. Add a line to the **Agent log** at the bottom for anything others must know.


## Project state

Rails 8.1 app (Ruby version in `.ruby-version`); the product is called **ohship** (`config.x.product_name`). The UI is replicated from `design-draft-claude-1.pen`. Check the code before assuming any feature exists.

`design-draft-claude-1.pen` is an encrypted Pencil design file (untracked). Access it only through the `pencil` MCP tools, never Read/Grep.

## Commands

- `bin/setup` — copy `.env`, start Postgres (docker compose, host port 5433), prepare DB, start server (`--skip-server` to skip); `bin/dev` — run the dev server
- `bin/rails test` — run unit/integration tests; single file: `bin/rails test test/models/foo_test.rb`; single test: `bin/rails test test/models/foo_test.rb:LINE`
- `bin/rails test:system` — Capybara/Selenium system tests (run separately in CI)
- `bin/rubocop` — lint (`rubocop-rails-omakase` style, configured in `.rubocop.yml`)
- `bin/ci` — runs the full local CI defined in `config/ci.rb` (setup, rubocop, bundler-audit, importmap audit, brakeman with `--exit-on-warn`, tests, seed replant). `.github/workflows/ci.yml` mirrors these steps; keep both in sync.

## Architecture

Standard Rails "Solid" stack with no Node build step:

- **Styling**: plain CSS in `app/assets/stylesheets`; design tokens in `tokens.css`, themed through `data-bg` / `data-accent` on `<html>`. Components read semantic variables only (`--ink`, `--accent`…), never raw hex.
- **Frontend**: Propshaft + importmap-rails (`config/importmap.rb`), Turbo, and Stimulus. Controllers in `app/javascript/controllers` are auto-pinned via `pin_all_from`. Add JS dependencies with `bin/importmap pin`, not npm.
- **Database**: PostgreSQL via `docker-compose.yml`. Production uses four databases (primary, cache, queue, cable) with their own migration paths (`db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate`) and schema files (`db/*_schema.rb`).
- **Background jobs / cache / websockets**: Solid Queue, Solid Cache, Solid Cable (configured in `config/queue.yml`, `cache.yml`, `cable.yml`, `recurring.yml`); `bin/jobs` runs the worker.
- **Deployment**: Docker + Kamal (`config/deploy.yml`, `.kamal/`), served via Thruster/Puma.
- **Auth**: Google/Microsoft OAuth only (OmniAuth, `User.from_omniauth`); no passwords. Cookie sessions via `Authentication` concern. In development, `/dev/sign_in?email=ines@orbitlabs.dev&to=/path` skips OAuth (seed with `bin/rails db:seed`). Tests sign in with `sign_in_as(user)` (`test/test_helper.rb`).
- **Integrations** (`app/models/integrations/`): workspace-level OAuth connections to Zoom, Google Meet and GitHub (`IntegrationConnection`, tokens encrypted). `Meeting#provision!` creates the call; `/webhooks/github` links PRs to tasks by key (e.g. APO-97). Credentials come from ENV (see `.env.example`); tests stub HTTP with WebMock.
- **Design reference**: UI is replicated from `design-draft-claude-1.pen` (icons are Lucide in `app/assets/icons`, rendered with `icon "name"`). Verify visually with headless Brave screenshots of `http://127.0.0.1:3000/...`.
- **Layout**: signed-in pages use `layout "app"` (top bar + framed content). Project pages call `project_header @project, active: :tab` (breadcrumbs, tabs, bare content) and live under `/projects/:key/…` through the `ProjectScoped` / `TopicScoped` controller concerns. Panels are `.split > .panel + .side`; the accent frame is drawn with a `::after` overlay so children never hide it.
- **Domain objects**: `Board` (sprint columns + XP), `Backlog`, `Timeline` (+ `CalendarExport` .ics), `Analytics`, `MeetingSlots`, `Chain.create_with_steps!`, `Client.onboard!`, `TimeOffRequest.balance_for`, `Topic.similar_to` (pg_trgm).
- **Gotchas**: on macOS parallel tests need `gssencmode: disable` in `config/database.yml` (libpq fork crash). In zsh never name a shell variable `path` (it is tied to `PATH`). Stimulus reserves `scope`, `element`, `application` etc. as controller properties — never assign to them. Quick-search palette: `/` or Ctrl/Cmd+Space (`spotlight_controller.js`, `Search`). Pipe `bin/rails test` to a file, not `| tail`, if output seems to hang.
- **Not built yet**: rediscussion analytics, undo toast, Teams.
- **Errors**: `config.exceptions_app = routes` → `ErrorsController#show` (branded, works signed out). Use `render_error(403)` instead of `head :forbidden`. Direct visits to `/404` etc. hit the static `public/*.html` files, so test real failures, not those URLs.
- **Sprints**: `Sprint#state` (planned/active/completed); `Project#active_sprint` is what the board, header and timeline use (there is no date-based "current sprint" any more). `Sprint#start!` completes the previous active sprint and carries unfinished tasks; a partial unique index enforces one active sprint per project. `Project#managed_by?(user)` gates sprint management.
- **Keyboard shortcuts**: add every shortcut to `config/keybindings.yml` and put `data-hotkey="<spec>"` on the clickable element (`hotkey_data(:id)` / `key_hint(:id)` helpers); `hotkeys_controller.js` on `<body>` does the rest and a test fails on unregistered specs. Don't reuse CSS class names for dialogs that the handler queries (`.keyhelp`, `.spotlight`). Browser check: `node script/check_keys.mjs`.
- **LLM**: `Llm` (`app/models/llm*`) is provider-agnostic: `LLM_ENABLED=claude|gemini|grok|gpt` + `LLM_API_KEY`. Call `Llm.client.complete(prompt, system:, json:)` and `Llm.enabled?`; never call a provider API directly. `Llm::Drafts` builds task/chain drafts from a topic. Tests use `with_llm("gemini") { }` and WebMock.
- **Chat**: `TaskMessage` and `TopicMessage` share the `ChatMessage` concern (parent reply, `edit!`, soft `remove!`); controllers share `ChatMessages`; views `messages/_message` + `messages/_composer`. Stimulus actions only work inside their controller's element, so cross-element features (Reply buttons → composer) use a document event (`chat:reply`).
- **Tenancy**: `Workspace` = tenant (status/plan/seats). Everything tenant-owned is reached through `Current.workspace` (never `Model.find` unscoped). Sign-up is invite-only (`Invitation`, `Workspace#allow_domain_join`, `PLATFORM_ADMIN_EMAILS`); `User::Omniauth::NotInvited` is the refusal. `users.platform_admin` marks ohship staff.
- **Backoffice**: `Backoffice::*` controllers (layout `backoffice`) inherit `Backoffice::BaseController`, which 404s anyone but `platform_admin` users. Staff have no workspace, so never assume `Current.workspace` there.
- **Tenant access**: `ApplicationController#set_current_workspace` picks the tenant (session switcher → first active); `require_workspace_access` renders the suspended / no-workspace pages. Controllers that must work regardless (errors, sign out, switcher, backoffice) `skip_before_action :require_workspace_access`. New tenant-owned routes need a case in `tenant_isolation_test.rb`.
- **Running locally**: `task start` / `task stop` / `task restart` / `task status` (Taskfile.yml; pid in tmp/pids/server.pid, output in log/server.out). go-task runs a limited shell: use `ps -p`, not `kill -0`.

## Agent log

- **agent1 (basics)**, branch `agent1/basics` (worktree `../shipup-agent1`, `DB_SUFFIX=_agent1`, port 3001): product renamed to **ohship** (lowercase wordmark, `config.x.product_name`); rocket logo from `logo.png` lives in `app/assets/images/logo.png` and is rendered by `shared/_logo_mark` as a CSS mask (follows `currentColor`); favicon is `public/icon.png`.
