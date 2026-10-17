---
name: shipup
description: Codebase guide for the shipup Rails 8.1 app. Use when working in this repository to build, lint, test, or understand the stack (Hotwire, importmap, PostgreSQL, Solid Queue/Cache/Cable, Kamal).
---

# shipup

## Project state

Rails 8.1 app (Ruby version in `.ruby-version`); the product is called **ShipUp** (`config.x.product_name`). The UI is replicated from `design-draft-claude-1.pen`. Check the code before assuming any feature exists.

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
- **Not built yet**: task chat, rediscussion analytics, undo toast, Teams.
- **Errors**: `config.exceptions_app = routes` → `ErrorsController#show` (branded, works signed out). Use `render_error(403)` instead of `head :forbidden`. Direct visits to `/404` etc. hit the static `public/*.html` files, so test real failures, not those URLs.
