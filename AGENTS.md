# AGENTS.md

A one-page brief for coding agents (Claude Code, Cursor, etc.) working in this repo.

## Stack
Rails 8.1 sample todo app. SQLite (development/test, via `sqlite3` gem). Hotwire (turbo-rails + stimulus-rails) over the Propshaft asset pipeline with importmap-rails. Views are vanilla ERB partials — no Bootstrap, no Tailwind, no view components. Test framework is **Minitest** (Rails default), with Capybara + Selenium for system tests. Solid Queue / Solid Cache / Solid Cable are bundled but no app-specific jobs exist yet.

## Commands
- Setup: `bin/setup` (installs gems, prepares db). One-off: `bin/rails db:prepare`
- Run dev server: `bin/dev` (or `bin/rails server`)
- Run all tests: `bin/rails test` and `bin/rails test:system`
- Lint: `bundle exec rubocop` (config: `.rubocop.yml`, rails-omakase)
- Security scan: `bundle exec brakeman`

## Conventions
- RESTful resource routes only (`resources :todos`); no custom routes unless justified. Member routes for non-CRUD actions like `toggle_priority`.
- Controllers respond via `respond_to do |format|` with `format.html`, `format.json`, and `format.turbo_stream` where the UI updates inline.
- Strong parameters live in a private `*_params` method per controller.
- Per-record views go in `app/views/todos/_todo.html.erb`; forms in `_form.html.erb`. Turbo Stream views are siblings named `<action>.turbo_stream.erb`.
- Use `dom_id(record)` for stable Turbo target IDs.
- Migrations must be reversible; prefer `change` blocks. Use `bin/rails generate migration` rather than hand-writing files.

## Don'ts
- No new gems without explicit approval — the dependency surface is intentionally small.
- No inline `<script>` tags in ERB; behavior goes through Stimulus controllers or Turbo.
- Never `skip_before_action :verify_authenticity_token` or otherwise weaken CSRF.
- Do not seed real or scraped user data; `db/seeds.rb` only, with synthetic values.
- Do not import models, migrations, or partials from other student projects — keep the schema scoped to this todo app.
- Do not use `rescue Exception` or swallow errors silently.
