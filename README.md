# Shipup

Rails 8 app (product name **ohship**): project management built around **topics** (conversations),
**tasks and chains** (the work), **meetings**, a sprint **board**, clients and team time off · project people and invitations.
The UI is replicated from `design-draft-claude-1.pen`.

## Changelog

Keep this section current: every change set adds a line here (newest first).

- **Connectors redesigned**: the setup wizard is now a *Connectors* page in the normal app shell, with a card per tool grouped as Meetings (Zoom, Google Meet, Teams soon), Code (GitHub, with a link to repositories) and AI (status of `LLM_ENABLED`). Each card shows its connection, and admins can connect, disconnect and pick the default meeting tool in place. Reachable from search ("connectors", "zoom", "github").
- **Search jumps to pages**: the palette (`/`) has a new *Pages* group that filters from the first keystroke: Account, Appearance, Keyboard shortcuts, Notifications, Time off, Connectors and People (admins), plus every project area ("Apollo Gateway · Board"). An empty palette lists the pages. Backed by `Search::Pages`.
- **Calmer top bar and project header**: nothing wraps any more (breadcrumbs, timer pill, tabs), icon buttons are 36px, tab chord hints only show on hover, the workspace switcher hides when you only have one, and the first clock is labelled "You" with your UTC offset (e.g. `You UTC+1 11:58`).
- **Test databases**: parallel test workers are capped at 4 (was one per CPU core, which left a dozen `shipup_test_N` databases behind); `task db:clean-test` drops them.
- **Backoffice removed**: ohship is self-deployed, so there is no platform backoffice. Superadmin emails get admin membership of a built-in `ohship` workspace (`Workspace.instance`) on sign-in and land straight on the dashboard.
- **Meeting scheduler**: pick any date from a calendar and any time (5-minute steps) instead of a fixed list; times are read in your own time zone (DST-correct), past times are refused, the best-overlap slots stay as one-click chips, and each invitee row shows their local time and turns red when it falls outside their working hours.
- **Appearance, much more powerful** (Account → Appearance): five backgrounds (incl. *match system* light/dark), the five accents plus **any custom colour** (the soft/ink/tint family is derived with `color-mix()` and text stays readable), six fonts (Exo 2, Inter, Atkinson Hyperlegible, Source Serif, JetBrains Mono, system), density, text size, corner roundness, offset-shadow, high-contrast and reduce-motion switches, all previewed live and applied through `<html>` data attributes (`Appearance` model, rules at the end of `tokens.css`). Inside a project, **drag the tabs** (Topics, Backlog, Board…) to reorder your menu; the order is saved per person (`ProjectTabs`, `tab_sort_controller.js`).
- **Customizable keyboard shortcuts** (Account → Shortcuts, or "Customize" in the `?` dialog): click a shortcut, press the new keys, save. Only combinations that work in every browser are accepted (a letter, digit, `/` or `?`, or a two-key chord; Ctrl/Cmd/Alt combos belong to the browser), conflicts are detected per context (two shortcuts may share a key only if they are never active together), and `Esc`/`Ctrl+Enter` are fixed. Remaps are per person (`user_preferences.keybindings`). Views no longer hard-code keys: they use `hotkey_data(:id)` / `key_hint(:id)`; `config/keybindings.yml` holds the registry with contexts.
- **Notifications** are real now: the bell links to an inbox (`g n`) with an unread dot. They are created for replies and @mentions in topic/task chat, task assignments, unlocked chain steps, new topics (opt-in) and meeting invites, always honouring each person's notification settings and never notifying you about your own actions (`Notification.notify`). Email delivery of these is not built yet.
- **Time zones**: a person's zone now follows their browser (a `browser_time_zone` cookie set by `timezone_controller.js`) until they pick one under Account → Time zone; the top-bar clocks start with their own city and every page renders dates in their zone (`Time.use_zone` around each request, storage stays UTC).
- Renamed the product to **ohship** and added the rocket logo (CSS-masked so it follows the theme colours) and a new favicon.
- `Taskfile.yml`: `task start | stop | restart | status | logs` manage the server and Postgres.
- **Single-tenant, project-based access** (replaces the multi-tenant SaaS, workspaces and backoffice): every customer gets their own deploy, so there is no workspace, plan, seat limit or platform staff. Two levels of admin: **superadmins** are the emails in `SUPERADMIN_EMAILS` (read into `config.x.superadmin_emails`, never stored, so removing an email revokes it; in development `ines@orbitlabs.dev` is the default) and may sign in without an invitation, create projects, connect integrations and see every project. **Project admins** (role `admin` on a project, the old "manager") invite people, change roles, plan sprints and archive things on that project; the other role is `member`. Sign-up is **invite-only per project**: an unknown email is refused unless a project admin or superadmin invited it from the project's *People* tab. Signing in consumes pending invitations; inviting someone who already has an account adds them at once. Everyone else sees only the projects they are on (`Project.visible_to(user)`, a 404 otherwise, pinned by `test/controllers/project_access_test.rb`).
- **Core clean-up actions**: clients can be archived (soft delete) and restored (*Clients → Archived*); topics can be canceled with an optional reason and reopened; tasks can be archived from the task page and restored from the backlog; projects can be completed and reopened from the project header. Archived tasks are hidden by `Task`'s default scope (`Task.archived` finds them).
- **Task chat** (design's right-hand "Chat" on a task) with direct replies (quoted), editing (author only, shows "edited") and removal (author, superadmins, project admins; soft delete so replies keep their quote). Topic threads got the same abilities through the shared `ChatMessage` concern and `messages/_message` partials.
- **LLM adapter**: pick a provider with `LLM_ENABLED=claude|gemini|grok|gpt` and `LLM_API_KEY` (optional `LLM_MODEL`, `LLM_BASE_URL`). `Llm.client.complete(prompt, system:, json:)` is the only API the app uses, so switching provider is configuration. First feature: *Draft with AI* / *Try another draft* on the create task and create chain pages (`Llm::Drafts`). Unset = AI features hidden. Add a provider by subclassing `Llm::Base`.
- Keyboard shortcuts rebuilt: one global handler (`hotkeys_controller.js`) driven by `data-hotkey` attributes and one registry, `config/keybindings.yml`, which also feeds the **?** help dialog. Navigation uses `g` chords (`g b` board, `g t` topics, `g h` projects…); primary actions use **Ctrl/Cmd+Enter**; no browser-owned combos (Ctrl+S, Space…). Project tabs now show the shortcuts of the *other* tabs, not the current one. `node script/check_keys.mjs` presses the real keys in a browser.
- Sprints have a state (planned, active, completed) with a unique-index guarantee of **one active sprint per project**. Create a sprint from the backlog (*Plan sprint*), start it (carrying unfinished tasks over if you like) and it shows on the board immediately; *Complete sprint* sits on the board. Superadmins and project admins manage sprints.
- Branded error pages (400, 403, 404, 406, 422, 500) rendered by `ErrorsController` via `config.exceptions_app`; static `public/*.html` fallbacks restyled. Forbidden actions render the 403 page.
- Fix: project cards on the dashboard now open the project. Product renamed from Nook to **ohship**.

## Stack

Rails 8.1 · PostgreSQL · Hotwire (Turbo + Stimulus) · importmap · Propshaft (plain CSS + design
tokens) · Solid Queue/Cache/Cable · Minitest + WebMock · Kamal.

## Getting started

```sh
bin/setup        # copies .env, starts Postgres (docker compose), prepares the DB, runs the server
bin/rails db:seed  # demo data from the design (Orbit Labs, Apollo Gateway, …)
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
node script/check_appearance.mjs          # browser smoke test of appearance settings and tab drag-and-drop
node script/check_keys.mjs                # browser smoke test of keyboard shortcuts incl. remapping (server running; CHROMIUM_BIN, BASE optional)
```

## Sign-in and integrations

Google and Microsoft OAuth are the only ways in (no passwords). Superadmins connect **Zoom**,
**Google Meet** and **GitHub** under *Integrations* (`/integrations`). Credentials live in `.env`
(see `.env.example`):

| Feature | Variables | Redirect URI |
| --- | --- | --- |
| Sign in with Google | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET` | `/auth/google_oauth2/callback` |
| Sign in with Microsoft | `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET`, `MICROSOFT_TENANT_ID` | `/auth/entra_id/callback` |
| Zoom meetings | `ZOOM_CLIENT_ID`, `ZOOM_CLIENT_SECRET` | `/integrations/zoom/callback` |
| Google Meet links | reuses the Google client (add the Calendar scope) | `/integrations/google_meet/callback` |
| Superadmin(s) | `SUPERADMIN_EMAILS` (comma separated; they can sign in without an invitation) | – |
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

Sign in · setup (meeting tool, GitHub) · projects home and new project · topics (list,
thread, new with similar-topic suggestions, voting) · Move on → create task / chain · meet about it
(Zoom / Google Meet) · backlog and sprint planning · sprint board (drag and drop, keyboard) · task
page with time tracker · timeline (with `.ics` export) · clients · analytics · account · appearance ·
time off · project people and invitations.
Quick search ("Super Space": `/` or Ctrl/Cmd+Space) covers topics, tasks and projects.
Not built yet from the design: rediscussion analytics, undo toast
and Microsoft Teams meetings.
