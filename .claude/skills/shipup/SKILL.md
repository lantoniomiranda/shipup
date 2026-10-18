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
- **Auth**: Google/Microsoft OAuth only (OmniAuth, `User.from_omniauth`); no passwords. Cookie sessions via `Authentication` concern. In development, `/dev/sign_in?email=ines@orbitlabs.dev&to=/path` skips OAuth for an existing user (the app starts empty; `task db:demo` loads sample people from `db/demo.rb`). Tests sign in with `sign_in_as(user)` (`test/test_helper.rb`).
- **Integrations** (`app/models/integrations/`): deploy-wide OAuth connections to Zoom, Google Meet and GitHub (`IntegrationConnection`, one per provider, tokens encrypted; the chosen meeting tool is `Setting.meeting_provider`, admins only). `Meeting#provision!` creates the call; `/webhooks/github` links PRs to tasks by key (e.g. APO-97). Credentials come from ENV (see `.env.example`); tests stub HTTP with WebMock.
- **Design reference**: UI is replicated from `design-draft-claude-1.pen` (icons are Lucide in `app/assets/icons`, rendered with `icon "name"`). Verify visually with headless Brave screenshots of `http://127.0.0.1:3000/...`.
- **Layout**: signed-in pages use `layout "app"` (top bar + framed content). Project pages call `project_header @project, active: :tab` (breadcrumbs, tabs, bare content) and live under `/projects/:key/…` through the `ProjectScoped` / `TopicScoped` controller concerns. Panels are `.split > .panel + .side`; the accent frame is drawn with a `::after` overlay so children never hide it.
- **Domain objects**: `Board` (sprint columns + XP), `Backlog`, `Timeline` (+ `CalendarExport` .ics), `Analytics`, `MeetingSlots`, `Chain.create_with_steps!`, `Client.onboard!` (global, soft-deleted with `archive!`/`restore!`), `TimeOffRequest.balance_for`, `Topic.similar_to` (pg_trgm).
- **Gotchas**: on macOS parallel tests need `gssencmode: disable` in `config/database.yml` (libpq fork crash). In zsh never name a shell variable `path` (it is tied to `PATH`). Stimulus reserves `scope`, `element`, `application` etc. as controller properties — never assign to them. Quick-search palette: `/` or Ctrl/Cmd+Space (`spotlight_controller.js`, `Search`). New top-level pages go into `Search::Pages` so they are reachable from it. Pipe `bin/rails test` to a file, not `| tail`, if output seems to hang.
- **Not built yet**: rediscussion analytics, undo toast, Teams.
- **Errors**: `config.exceptions_app = routes` → `ErrorsController#show` (branded, works signed out). Use `render_error(403)` instead of `head :forbidden`. Direct visits to `/404` etc. hit the static `public/*.html` files, so test real failures, not those URLs.
- **Sprints**: `Sprint#state` (planned/active/completed); `Project#active_sprint` is what the board, header and timeline use (there is no date-based "current sprint" any more). `Sprint#start!` completes the previous active sprint and carries unfinished tasks; a partial unique index enforces one active sprint per project. `Project#managed_by?(user)` gates sprint management.
- **Settings**: one area replaces the old Account page (design: "Settings · …" frames in `design-draft-claude-1.pen`). Controllers use `layout "settings"` (left menu in `settings/_nav`, current section = controller name): `AccountsController` (/settings/account: name, avatar, login), `LanguageSettingsController` (language, time zone, working hours), `AppearancesController`, `NotificationSettingsController` (email prefs; the inbox is `NotificationsController`), `KeyboardSettingsController`, `IntegrationsController` (/settings/connectors, superadmin only). A new section needs an entry in the nav, `settings.<key>.{title,hint}` in every locale and an entry in `Search::Pages`.
- **Search**: `Search` is global (pages incl. every settings section, topics, tasks, chains, projects). Opened inside a project the palette sends `project=<key>` (`data-spotlight-url-value` in `layouts/app`) and the results show that project's topics, tasks and chains first under "In <project>"; invisible projects are ignored as context.
- **Keyboard shortcuts**: add every shortcut to `config/keybindings.yml` (with a `context`) and put `data: hotkey_data(:id)` / `key_hint(:id)` on the element — never a literal key (a test fails on literals; people can remap shortcuts, see `Keybindings.keys` / `UserPreference#remap_keybindings!`); `hotkeys_controller.js` on `<body>` does the rest and a test fails on unregistered specs. Don't reuse CSS class names for dialogs that the handler queries (`.keyhelp`, `.spotlight`). Browser check: `node script/check_keys.mjs`.
- **Avatars**: always render people with `avatar(user, size:)` (icon from `User::AVATAR_ICONS` on their colour, initials in `aria-label`); never build avatar markup by hand. Key caps in `.tab` must stay visible (no `display:none` rule; a test checks).
- **LLM**: `Llm` (`app/models/llm*`) is provider-agnostic: `LLM_ENABLED=claude|gemini|grok|gpt` + `LLM_API_KEY`. Call `Llm.client.complete(prompt, system:, json:)` and `Llm.enabled?`; never call a provider API directly. `Llm::Drafts` builds task/chain drafts from a topic. Tests use `with_llm("gemini") { }` and WebMock.
- **Chat**: `TaskMessage` and `TopicMessage` share the `ChatMessage` concern (parent reply, `edit!`, soft `remove!`); controllers share `ChatMessages`; views `messages/_message` + `messages/_composer`. Stimulus actions only work inside their controller's element, so cross-element features (Reply buttons → composer) use a document event (`chat:reply`).
- **Access (single-tenant)**: one deploy per customer, so there is **no workspace/tenant/backoffice**; do not reintroduce `Current.workspace`. Two admin levels. **Superadmin** = email in `SUPERADMIN_EMAILS` (`config.x.superadmin_emails`, set in `config/application.rb`; dev default and test list in `config/environments/{development,test}.rb`); it is derived (`User#superadmin?`), never a DB column, so tests change it by assigning `Rails.configuration.x.superadmin_emails`. Superadmins create projects, connect integrations (`require_superadmin`) and see every project. **Project admin** = `ProjectMembership` role `admin` (other role: `member`); `Project#managed_by?(user)` is superadmin-or-project-admin and `require_project_admin` gates management actions. Always look projects up with `Project.visible_to(Current.user)` (done by `ProjectScoped`; a miss is a 404). People reach a project through `Invitation` (belongs to a project, role admin/member): sign-up is invite-only, `User::Omniauth::NotInvited` is the refusal, sign-in consumes pending invitations and inviting an existing user adds them at once. UI is the project's *People* tab (`ProjectMembersController`, `InvitationsController`). Other people-scopes: `User#teammates` (time off, clocks), `User#approver?`. New project routes need a case in `test/controllers/project_access_test.rb`.
- **Soft delete / cancel**: `Client#archive!`/`restore!` (`archived_at`; use `Client.active` in pickers), `Task#archive!`/`restore!` (`Task` has a default scope hiding archived rows; use `Task.archived` to find them, and remember raw SQL on `tasks` needs `archived_at IS NULL`), `Topic#cancel!`/`reopen!` (posts a thread message), project `completed`/`active` via `ProjectsController#update`. Prefer these over `destroy`.
- **Running locally**: `task start` / `task stop` / `task restart` / `task status` (Taskfile.yml; pid in tmp/pids/server.pid, output in log/server.out). go-task runs a limited shell: use `ps -p`, not `kill -0`.

## Agent log

- **agent1 (basics)**, branch `agent1/basics` (worktree `../shipup-agent1`, `DB_SUFFIX=_agent1`, port 3001): product renamed to **ohship** (lowercase wordmark, `config.x.product_name`); rocket logo from `logo.png` lives in `app/assets/images/logo.png` and is rendered by `shared/_logo_mark` as a CSS mask (follows `currentColor`); favicon is `public/icon.png`.
  - There is deliberately **no landing page**: ohship is self-deployed, so `/` sends visitors straight to the sign-in page. Don't add marketing pages.
  - Time zones: `users.time_zone_set_by_user` false = follow the `browser_time_zone` cookie (`ApplicationController#follow_browser_time_zone`); `use_user_time_zone` wraps requests in `Time.use_zone`. Use `Time.zone`/`in_time_zone`, never assume UTC in views.
  - Notifications: create them only through `Notification.notify(user:, kind:, subject:, actor:)` (respects settings, skips the actor). Hooks live in `ChatMessage`, `Task`, `Topic`, `MeetingParticipant`; text and links in `NotificationsHelper`. In model tests set the actor with `Current.session = Session.new(user: u)`.
  - Keybindings: shortcuts handled by dedicated JS (search `/`, composer reply, board keys) receive their key through a Stimulus value (`data-spotlight-key-value`, `data-composer-key-value`, `data-board-keys-value`); mark such entries `single_key: true` in the YAML. `check_keys.mjs` reads `CHROMIUM_BIN` (not `BROWSER`, which this environment sets to `true`).
  - Appearance: `Appearance` (app/models) renders a person's `UserPreference` into `<html>` data attributes + inline `--zoom`/accent vars; CSS reacts in the last section of `tokens.css`. Use `var(--vh)` instead of `100vh` (html is zoomed), `var(--btn-shadow)`/`--lift-shadow` instead of literal hard shadows, and radius tokens for corners. Project tabs come from `ProjectTabs.for(user)` (ids are strings: call `.to_sym` for `hotkey_data`/`key_hint`). `node script/check_appearance.mjs` verifies live preview, zoom and tab drag-and-drop in a browser.
  - Meetings: `TopicMeetingsController#create` reads `date` + `time` in `Time.zone` (the person's zone via `use_user_time_zone`); `starts_at` ISO8601 is still accepted. The form logic (invitee local times, working-hours flags) is `meeting_form_controller.js`.
- **agent1 status**: branch `agent1/basics` (8 commits on top of `20ad8e9`) holds: ohship rename + logo, browser time zone, notifications, remappable shortcuts, appearance + tab reordering, meeting scheduler. It was built in a separate worktree because another agent was removing multi-tenancy in the main tree at the same time; **merge it only after that work is committed**, expect conflicts in `layouts/_top_bar`, `ApplicationController`, `AccountsController`, `config/routes.rb`, `db/schema.rb` (regenerate with `db:migrate` rather than hand-merging), README and this file. Its migrations: `20261018110001`, `20261018120001`.

