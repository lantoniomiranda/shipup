# Shipup

Rails 8 app (product name **ShipUp**): project management built around **topics** (conversations),
**tasks and chains** (the work), **meetings**, a sprint **board**, clients and team time off.
The UI is replicated from `design-draft-claude-1.pen`.

## Changelog

Keep this section current: every change set adds a line here (newest first).

- Sprints have a state (planned, active, completed) with a unique-index guarantee of **one active sprint per project**. Create a sprint from the backlog (*Plan sprint*), start it (carrying unfinished tasks over if you like) and it shows on the board immediately; *Complete sprint* sits on the board. Workspace admins and project managers manage sprints.
- Branded error pages (400, 403, 404, 406, 422, 500) rendered by `ErrorsController` via `config.exceptions_app`; static `public/*.html` fallbacks restyled. Forbidden actions render the 403 page.
- Fix: project cards on the dashboard now open the project. Product renamed from Nook to **ShipUp**.

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

```sh
bin/dev                                   # run the server
bin/rails test                            # unit + integration tests
bin/rails test test/models/x_test.rb:12   # a single test
bin/rubocop                               # lint
bin/ci                                    # everything CI runs
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
Not built yet from the design: task chat, rediscussion analytics, undo toast
and Microsoft Teams meetings.
