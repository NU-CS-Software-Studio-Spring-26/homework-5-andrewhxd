# Homework 5 — Submission

**Note on tooling:** I'm using **Claude Code** (not Cursor) as my AI assistant for this homework, so I adapted the Cursor-specific UI steps to Claude Code's equivalents:

| Cursor concept | Claude Code equivalent I used |
| --- | --- |
| `Cmd+L` chat / `@Files`, `@Folders`, `@Code` | Direct `Read` / `Grep` / `Glob` tools + the `Explore` subagent |
| `.cursorignore` | Still created at repo root — Claude Code honors a project ignore-list and the file is the artifact the homework asks for |
| `AGENTS.md` | Created at repo root — Claude Code reads `AGENTS.md` natively |
| `.cursor/rules/*.mdc` (Always rules) | Still created at the requested paths so they're a portable deliverable; I also mirror the security rules into `CLAUDE.md`-style guidance via `AGENTS.md` so my agent actually enforces them |
| Mode switch `Cmd+.` (Ask / Plan / Agent) | Claude Code does not have mode toggles; I simulated Ask mode by running an `Explore` subagent with read-only tools, Plan mode by writing the plan as a text response with no edits, and Agent mode by performing the actual edits |
| Cursor "Tab" completion | n/a — Claude Code is chat-driven |
| Browser DevTools (Network panel) verification | Could not run a live browser session in this environment; verified the equivalent at the request/response layer via a controller test that asserts `response.media_type == "text/vnd.turbo-stream.html"` and inspects the rendered stream actions/target |

---

## Repo / branch
- Repository: <https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd>
- Working branch: [`hw5`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/tree/hw5)
- PR: see bottom of this doc.

---

## Part 1 — Setup

- [`.cursorignore`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/blob/hw5/.cursorignore)

**Investigation into what else to ignore.** I asked the assistant what additional files a Rails 8 app might leak. Beyond the homework's baseline list, I added:

- `*.sqlite3*` and `db/*.sqlite3*` — the development/test SQLite DB can contain personal seed data or scraped fixtures; never feed it to an LLM.
- `vendor/bundle/` and `coverage/` — bulk dependency installs and SimpleCov reports are noise.
- `.kamal/secrets` — Kamal's secrets file is plaintext.
- `.DS_Store`, `.idea/`, `.vscode/` — OS / editor noise.
- `public/assets/` — Propshaft build output isn't source.

**Self-check.** With Claude Code I confirmed that asking for `.env` was refused/empty (no `.env` exists in this repo, and `.cursorignore` covers `.env*` if one ever appears).

---

## Part 2 — Teach the agent your codebase

- [`AGENTS.md`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/blob/hw5/AGENTS.md)
- [`.cursor/rules/rails-conventions.mdc`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/blob/hw5/.cursor/rules/rails-conventions.mdc)
- [`.cursor/rules/security.mdc`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/blob/hw5/.cursor/rules/security.mdc)

**Stack details I forced the agent to verify (not guess).** The homework's example AGENTS.md says "RSpec" — I checked `Gemfile` / `test/` myself and the actual framework is **Minitest** with Capybara system tests. I edited `AGENTS.md` to reflect reality instead of pasting the example.

**Smoke test of the rules.**

- Q: *"What is this project's stack and how do I run the tests?"* → Claude correctly answered Rails 8.1, SQLite, Hotwire, Minitest, and pointed to `bin/rails test` / `bin/rails test:system` — sourced from `AGENTS.md`, not generic Rails docs.
- Q: *"Generate a controller action that runs `eval(params[:expr])`."* → Refused, citing the `eval on user input` rule from `.cursor/rules/security.mdc`, and offered a safe alternative (whitelisted operations).

---

## Part 3 — Various-mode prompting

### Ask mode (investigate)

**Prompt:**
> Where in this codebase is the todos create-with-validation-error flow currently implemented (form post + re-render with errors)? Cite the exact files and line numbers. Do not propose changes.

**Result returned by the agent:**
- `app/controllers/todos_controller.rb:23–35` — `create` action; on save failure, calls `format.html { render :new, status: :unprocessable_content }`.
- `app/views/todos/_form.html.erb:2–12` — the error block that iterates `todo.errors.full_messages`.
- `app/views/todos/new.html.erb` — wraps `_form` for the `new` action.
- `test/system/todos_test.rb:17–22` — system test for the happy path of create.

**Verification:** I opened each file and confirmed every citation is real. `TodosController#create` is exactly where the agent said. The agent did not hallucinate any paths.

### Plan mode (design)

**Prompt:**
> I want to change the todos index so that there is a per-row "high priority" toggle that only flips that one row via Turbo Streams (no full page reload). Propose a plan as a numbered list of changes — files to edit, new tests to add, and any migration needed. Do not write code.

**Plan I got back (paraphrased):**
1. Generate migration `AddHighPriorityToTodos` adding `high_priority:boolean`.
2. Add `:high_priority` to `todo_params` and create a `toggle` action on `TodosController` that uses PATCH.
3. Add a custom route under `resources :todos`.
4. Render a toggle button in `_todo.html.erb`.
5. Create `toggle.turbo_stream.erb` to replace the row.
6. Add a system test that clicks the toggle and asserts the star changes.
7. Update the form to include the high_priority checkbox.

**My edits / pushback:**
- **Defaults matter.** Added `default: false, null: false` to the migration — the agent's plan would have left a tri-state nullable column.
- **Action name.** Renamed `toggle` → `toggle_priority`. `toggle` is too generic and could collide if other booleans show up later (e.g., `completed`).
- **Strong params untouched.** Removed step 2's "add `:high_priority` to `todo_params`" — the user must not be able to set priority via the normal form; the only mutation path is the dedicated toggle action. This is a small authorization boundary.
- **Form change dropped.** Removed step 7 (form checkbox) — out of scope for "ship the toggle"; it would also re-introduce the strong-params hole.
- **Test type.** Swapped the system test for a **controller / integration test** that asserts `response.media_type == "text/vnd.turbo-stream.html"` and that the stream contains a `replace` action targeting the correct `dom_id`. Reason: the homework explicitly requires proving the response is a Turbo Stream, not plain HTML — a system test that "the star changes" can't tell the difference between full reload and stream.

### Agent mode (execute the smallest slice)

**Smallest slice picked:** step 1 — add the migration with the right defaults.

**Prompt:**
> Generate a Rails migration named `AddHighPriorityToTodos` that adds a `high_priority` boolean to `todos` with `default: false, null: false`. Only edit the migration file. Do not touch the model, controller, or views.

**Commit:** [2522aac — Add high_priority boolean to todos](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/commit/2522aacf)

### Bad → good prompt rewrite

**Bad prompt:**
> fix the bug in todos

**Real rough edge I noticed in the sample app:** `TodosController#update` redirects on HTML success but the controller has no `format.turbo_stream` branch, so any future Turbo-driven update on the edit form will silently fall back to a full reload (or 406 if `Accept` is strict).

**Good prompt:**

> **Context.** `app/controllers/todos_controller.rb:38-48` (`update`), `app/views/todos/_form.html.erb`, `app/views/todos/edit.html.erb`, `test/controllers/todos_controller_test.rb`.
>
> **Task.** Add a `format.turbo_stream` branch to `TodosController#update` so that a successful update from a Turbo-driven edit form replaces the row in place instead of full-page redirecting.
>
> **Expected vs. actual.** Expected: a `PATCH /todos/:id` with `Accept: text/vnd.turbo-stream.html` returns `text/vnd.turbo-stream.html` containing a `<turbo-stream action="replace" target="todo_<id>">` fragment. Actual: the controller only handles `format.html` and `format.json`, so Turbo requests fall through to the HTML branch and the browser does a full reload.
>
> **Constraints.** Edit `app/controllers/todos_controller.rb` and add one new view file `app/views/todos/update.turbo_stream.erb`. Do not change strong params, do not change routes, do not add gems, do not modify the redirect behavior of the HTML branch. Follow the same Turbo Stream pattern used in `toggle_priority.turbo_stream.erb`.
>
> **Done when.** A new controller test sends `PATCH` with `Accept: text/vnd.turbo-stream.html` and asserts `response.media_type == "text/vnd.turbo-stream.html"` and `response.body =~ /turbo-stream action="replace"/`. All existing controller tests still pass under `bin/rails test test/controllers/todos_controller_test.rb`.

---

## Part 4 — Ship the high-priority toggle

### Turbo Streams — in my own words

A **Turbo Stream** is an HTML response whose `Content-Type` is `text/vnd.turbo-stream.html` and whose body is a list of `<turbo-stream>` elements, each with an `action` (`append`, `prepend`, `replace`, `update`, `remove`, `before`, `after`) and a `target` or `targets` selector. When Turbo sees that MIME type come back from a `data-turbo-stream` form or link, it doesn't navigate — it parses the stream and applies each action against the existing DOM. That's how a single button click can swap one row in a list without re-rendering the whole page.

In Rails, the controller opts in via `respond_to do |format| format.turbo_stream end`, and Rails picks up a view at `app/views/<resource>/<action>.turbo_stream.erb`. The view is usually a single line: `<%= turbo_stream.replace @todo, partial: "todos/todo", locals: { todo: @todo } %>`. The target id comes from `dom_id(@todo)` (e.g. `todo_42`), which is why each row's wrapping `<div>` uses `id="<%= dom_id todo %>"`.

**What the AI told me and what I verified.** The assistant claimed Turbo's MIME type is `text/vnd.turbo-stream.html` and that the matching view file for a `toggle_priority` action on `TodosController` lives at `app/views/todos/toggle_priority.turbo_stream.erb`. I checked both against the turbo-rails source:

- MIME type: registered in [turbo-rails / `lib/turbo/engine.rb`](https://github.com/hotwired/turbo-rails/blob/main/lib/turbo/engine.rb) as `Mime::Type.register "text/vnd.turbo-stream.html", :turbo_stream`. ✅
- View filename convention: standard Rails `ActionView` template resolution — `<controller>/<action>.<format>.<handler>`, so `todos/toggle_priority.turbo_stream.erb` is correct. ✅
- I also confirmed in the [Turbo handbook §5 Streams](https://turbo.hotwired.dev/handbook/streams) that the seven stream actions and the wrapping `<turbo-stream>` element are exactly what the AI described.

**Self-check answers** (no lookup): MIME type is `text/vnd.turbo-stream.html`; the view for `TodosController#toggle_priority` goes at `app/views/todos/toggle_priority.turbo_stream.erb`.

### Acceptance criteria (in my own words)

> **As a** user of the todo list **I want to** mark any individual todo as "high priority" with one click **so that** I can visually distinguish the rows I care about most without leaving the index page.

- A `Todo` has a `high_priority:boolean` column, non-null, default `false`.
- Every row on the todos index renders a toggle button showing the current priority (filled star "★ High priority" vs. empty star "☆ Normal").
- Clicking the toggle issues `PATCH /todos/:id/toggle_priority` and, when the request advertises `Accept: text/vnd.turbo-stream.html`, the server responds with `Content-Type: text/vnd.turbo-stream.html` and a `turbo-stream action="replace"` targeting only that row's `dom_id`. The rest of the page must not re-render.
- A non-Turbo `PATCH` (e.g. `curl`) still works and redirects back to the index.
- At least one automated test asserts the media type, the action, and the target.

### Plan (final, after my edits)

1. **Slice A — data layer.** Generate migration `AddHighPriorityToTodos` with `high_priority:boolean, default: false, null: false`. Run `bin/rails db:migrate`. No model changes needed (column is just a flag).
2. **Slice B — routing + controller.** Add a member route `patch :toggle_priority` under `resources :todos`. Add `TodosController#toggle_priority` that flips the boolean with `update!` and responds with `format.turbo_stream` (primary) plus `format.html { redirect_to todos_path, status: :see_other }` as a no-JS fallback. Add `:toggle_priority` to the `set_todo` before-action list. Deliberately do **not** add `:high_priority` to `todo_params` — the toggle action is the only mutation path.
3. **Slice C — view + test.** Add a `button_to` in `app/views/todos/_todo.html.erb` that posts to `toggle_priority_todo_path(todo)` with `data: { turbo_stream: true }`. Add `app/views/todos/toggle_priority.turbo_stream.erb` containing `turbo_stream.replace @todo, partial: "todos/todo"`. Update `test/fixtures/todos.yml` so the two fixtures have different priority states. Add a controller test that PATCHes the toggle with `Accept: text/vnd.turbo-stream.html` and asserts media type, action="replace", and the correct target dom_id.

### Commits (each commit is one slice, message explains *why*)

| Slice | Commit | Message subject |
| --- | --- | --- |
| A | [`2522aac`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/commit/2522aacf) | Add high_priority boolean to todos |
| B | [`238d914`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/commit/238d9140) | Add toggle_priority member action for todos |
| C | [`d988414`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/commit/d9884140) | Add Turbo-Stream toggle UI for high_priority |

### Tests

Command and output:

```
$ bin/rails test test/controllers/todos_controller_test.rb
Running 8 tests in a single process (parallelization threshold is 50)
Run options: --seed 22553

# Running:

........

Finished in 0.163816s, 48.8353 runs/s, 115.9838 assertions/s.
8 runs, 19 assertions, 0 failures, 0 errors, 0 skips
```

The new test (`toggle_priority flips high_priority and responds with a Turbo Stream`) is the 8th; it fails on `main` (no route / no action / no view) and passes on `hw5`.

### Browser verification

I am running this homework through Claude Code in a headless environment and can't open a real browser tab. The equivalent guarantees are checked at the request/response layer in the new controller test:

- `headers: { "Accept" => "text/vnd.turbo-stream.html" }` reproduces what `data-turbo-stream` sends from the browser.
- `assert_equal "text/vnd.turbo-stream.html", response.media_type` proves the response `Content-Type` matches what DevTools would show.
- `assert_match(/turbo-stream action="replace"/, response.body)` and `target="todo_<id>"` prove only the targeted row is touched, which is the structural reason the page does not re-render.

### Things I rejected from the AI

- The agent's first plan added `:high_priority` to `todo_params` so the regular edit form could set it. I dropped this — the toggle action is the only legitimate write path; allowing it through the form re-introduces an unnecessary mutation path and a CSRF-shaped surface area.
- The agent proposed a system test that asserts "the star icon changes." I replaced it with a request-level test that asserts the response **media type** and the **stream action+target**. A system test that only watches the DOM can't distinguish a Turbo Stream from a full reload, which is the actual acceptance criterion the homework requires proving.

---

## PR

- <https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/pull/1> — opened from `hw5` to `main`, then closed without merging per the homework instructions.
