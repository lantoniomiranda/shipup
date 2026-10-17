# Shipup

Rails 8 app (product name **Nook**): project management built around topics,
chains, meetings and a sprint board. Design source: `design-draft-claude-1.pen`.

## Stack

Rails 8.1, PostgreSQL, Hotwire (Turbo + Stimulus), importmap, Propshaft (plain
CSS with design tokens), Solid Queue/Cache/Cable, Minitest.

## Getting started

```sh
bin/setup        # copies .env, starts Postgres via docker compose, prepares the DB, runs the server
```

Postgres listens on `localhost:5433` (see `docker-compose.yml`, overridable in `.env`).

## Everyday commands

```sh
bin/dev                              # run the server
bin/rails test                       # unit + integration tests
bin/rails test test/models/x_test.rb:12   # a single test
bin/rubocop                          # lint
bin/ci                               # everything CI runs
```

## Theming

`app/assets/stylesheets/tokens.css` holds the design tokens. Backgrounds
(`paper`, `mist`, `sage`, `night`) and accents (`orange`, `blue`, `teal`,
`plum`, `mustard`) are switched with `data-bg` / `data-accent` on `<html>`.
