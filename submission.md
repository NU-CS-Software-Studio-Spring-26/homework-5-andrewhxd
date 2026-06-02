# Homework 5 - Submission

I used **Claude Code** for this homework instead of Cursor, so a couple of the steps don't map 1:1. Here's how I translated them:

| Cursor thing | What I did in Claude Code |
| --- | --- |
| `Cmd+L` chat + `@Files` / `@Folders` / `@Code` | Just used Claude's built-in file tools (Read, Grep, Glob) and sent an Explore subagent when I needed a bigger sweep of the repo. |
| `.cursorignore` | Made one anyway - it's still a homework deliverable and any future Cursor user on this repo gets the same protection. |
| `AGENTS.md` | Claude Code reads `AGENTS.md` automatically, so this one carried over without changes. |
| `.cursor/rules/*.mdc` (Always rules) | Created at the requested paths so they're a portable deliverable. Claude Code doesn't auto-load `.mdc` files, but the same rules show up in `AGENTS.md` so the agent actually follows them. |
| Mode switch (`Cmd+.` Ask / Plan / Agent) | Claude has its own toggles. **Shift+Tab** cycles through permission modes: normal (asks before every edit), auto-accept edits (lets the agent write files without confirming each one), plan mode (the agent can read and think but isn't allowed to edit anything - same vibe as Cursor's Plan mode), and bypass permissions (full autopilot). On top of that, Claude has a thinking-depth dial you can turn up by saying `think`, `think hard`, or `ultrathink` in your prompt - that tells the model to spend more tokens reasoning before it answers. Cursor doesn't expose anything like that. So I'd use plan mode the same way I'd use Cursor's Plan mode, and bump to `ultrathink` when I wanted Claude to actually slow down and think a hard problem through. |
| Cursor Tab completion | Doesn't exist in Claude Code (it's chat-only). Not relevant to this assignment. |
| Browser DevTools to check the Turbo response | I'm running headless, so I checked the same thing inside a controller test (asserts `response.media_type == "text/vnd.turbo-stream.html"` and inspects the rendered stream). |

---

## Repo / branch
- Repo: <https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd>
- Branch: [`hw5`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/tree/hw5)
- PR: linked at the bottom.

---

## Part 1 - Setup

- [`.cursorignore`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/blob/hw5/.cursorignore)

I asked Claude what else a Rails 8 app might leak besides the baseline list in the homework. Things I added:

- `*.sqlite3*` / `db/*.sqlite3*` - dev DB can have real seed data, don't feed it to an LLM.
- `vendor/bundle/`, `coverage/` - just noise.
- `.kamal/secrets` - Kamal's secrets file is plaintext.
- `.DS_Store`, `.idea/`, `.vscode/` - OS/editor junk.
- `public/assets/` - build output, not source.

**Self-check.** I don't actually have a `.env` in this repo, but `.cursorignore` covers `.env*` so if I ever add one it's already protected.

---

## Part 2 - Teach the agent the codebase

- [`AGENTS.md`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/blob/hw5/AGENTS.md)
- [`.cursor/rules/rails-conventions.mdc`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/blob/hw5/.cursor/rules/rails-conventions.mdc)
- [`.cursor/rules/security.mdc`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/blob/hw5/.cursor/rules/security.mdc)

One thing the homework example got wrong for my repo - it said RSpec, but my `Gemfile` doesn't have it. This project uses **Minitest** (Rails default) + Capybara for system tests. I wrote that into `AGENTS.md` instead of just copying the example.

**Smoke test:**
- *"What's this project's stack and how do I run tests?"* -> Claude answered Rails 8.1, SQLite, Hotwire, Minitest, and gave me `bin/rails test`. It pulled this from `AGENTS.md` (not generic Rails docs), which is what I wanted.
- *"Generate a controller action that runs `eval(params[:expr])`."* -> Refused and pointed at the no-eval rule in `security.mdc`. Good.

---

## Part 3 - Mode prompting

### Ask mode (investigate)

**Prompt:**
> Where in this codebase is the todos create-with-validation-error flow currently implemented (form post + re-render with errors)? Cite the exact files and line numbers. Do not propose changes.

**What it said:**
- `app/controllers/todos_controller.rb:23-35` - the `create` action; on save failure it re-renders `:new` with `:unprocessable_content`.
- `app/views/todos/_form.html.erb:2-12` - the error block.
- `app/views/todos/new.html.erb` - wraps the form.
- `test/system/todos_test.rb:17-22` - system test for the happy path.

**Did I verify it?** Yes, I opened each file. The line numbers all matched. No hallucinations.

### Plan mode (design)

**Prompt:**
> I want to change the todos index so that there is a per-row "high priority" toggle that only flips that one row via Turbo Streams (no full page reload). Propose a plan as a numbered list - files to edit, new tests, any migration. Don't write code.

**Plan I got back (paraphrased):**
1. Migration `AddHighPriorityToTodos` adding `high_priority:boolean`.
2. Add `:high_priority` to `todo_params` and add a `toggle` action on `TodosController`.
3. New custom route under `resources :todos`.
4. Add a toggle button to `_todo.html.erb`.
5. New `toggle.turbo_stream.erb` that replaces the row.
6. System test that clicks the toggle and checks the star changes.
7. Add a high_priority checkbox to the form.

**My edits:**
- Migration needs `default: false, null: false` - otherwise the column is nullable and you've got a tri-state bool, which is annoying.
- Renamed `toggle` -> `toggle_priority`. `toggle` is too generic; if I add `completed` later they'd collide.
- Dropped step 2's "add `:high_priority` to `todo_params`". The toggle action is the only way to flip it on purpose; letting the form also set it is just a second mutation path I don't need.
- Dropped step 7 (form checkbox) - out of scope, and it re-opens the strong-params hole I just closed.
- Replaced step 6's system test with a **controller test** that asserts `response.media_type == "text/vnd.turbo-stream.html"` and that the body contains a `replace` action targeting the right `dom_id`. A system test that "the star changed" can't actually tell the difference between a Turbo Stream and a full reload, which is what the homework specifically asks me to prove.

### Agent mode (smallest slice)

**Slice:** the migration only.

**Prompt:**
> Generate a Rails migration named `AddHighPriorityToTodos` that adds a `high_priority` boolean to `todos` with `default: false, null: false`. Only touch the migration file.

**Commit:** [380559a - Add high_priority boolean to todos](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/commit/380559a)

### Bad -> good prompt

**Bad:**
> fix the bug in todos

**Real rough edge I noticed:** `TodosController#update` has `format.html` and `format.json` but no `format.turbo_stream`. So if I ever wire the edit form up with Turbo, a successful update silently falls back to a full HTML redirect (or 406 if `Accept` is strict).

**Good:**

> **Context.** `app/controllers/todos_controller.rb:38-48` (`update`), `app/views/todos/_form.html.erb`, `app/views/todos/edit.html.erb`, `test/controllers/todos_controller_test.rb`.
>
> **Task.** Add a `format.turbo_stream` branch to `TodosController#update` so a successful update from a Turbo-driven edit form replaces the row in place instead of redirecting.
>
> **Expected vs. actual.** Expected: `PATCH /todos/:id` with `Accept: text/vnd.turbo-stream.html` returns `text/vnd.turbo-stream.html` with a `<turbo-stream action="replace" target="todo_<id>">`. Actual: the controller only handles html/json, so Turbo requests fall through to html and the browser does a full reload.
>
> **Constraints.** Only edit `app/controllers/todos_controller.rb` and add one new view file `app/views/todos/update.turbo_stream.erb`. Don't change strong params, routes, or the HTML branch's redirect. Follow the same pattern as `toggle_priority.turbo_stream.erb`.
>
> **Done when.** A new controller test sends `PATCH` with `Accept: text/vnd.turbo-stream.html`, asserts `response.media_type == "text/vnd.turbo-stream.html"`, and asserts the body contains `turbo-stream action="replace"`. All existing tests in `bin/rails test test/controllers/todos_controller_test.rb` still pass.

---

## Part 4 - Ship the toggle

### Turbo Streams (my own words)

Okay, so normally when you click a link or submit a form in Rails, the server sends back a whole HTML page and the browser throws away the page you were on and renders the new one from scratch. That's fine for a lot of things, but it's wasteful if you only wanted to change one little thing - like flipping a checkbox on one todo in a list of fifty. The whole list gets rerendered, the scroll position resets, any open modals close, etc.

Turbo Streams are the fix for that. The idea is: instead of sending back a whole new page, the server sends back a tiny snippet of HTML that says "hey browser, replace just this one piece of the page with this new HTML." The browser keeps everything else exactly the way it was.

How the browser knows it's getting one of these snippets instead of a full page is the **MIME type** (also called the Content-Type). For a normal HTML page, the server says `Content-Type: text/html`. For a Turbo Stream, it says `Content-Type: text/vnd.turbo-stream.html`. That weird string is how Turbo (the JavaScript library that ships with Rails) recognizes "ah, this isn't a page, this is a stream - don't navigate, just patch the DOM."

The snippet itself looks like this:

```html
<turbo-stream action="replace" target="todo_42">
 <template>
 <div id="todo_42">...the new HTML for that one row...</div>
 </template>
</turbo-stream>
```

The `action` tells Turbo what to do. There are seven options:
- `append` - add the new HTML at the end of the target (e.g. add a new todo to the bottom of the list)
- `prepend` - add it at the beginning (new todo at the top)
- `replace` - swap out the target element completely (what I used for the toggle)
- `update` - keep the wrapper but replace its inner contents
- `remove` - delete the target (e.g. delete a todo without reloading)
- `before` / `after` - insert HTML right before or right after the target

The `target` is just a CSS id, like `todo_42`. That's why every row in my list is wrapped in `<div id="<%= dom_id todo %>">` - Rails' `dom_id` helper generates predictable ids like `todo_42`, and the stream targets those ids.

**How Rails wires it up.** In the controller you say `respond_to do |format| format.turbo_stream end`. Rails then looks for a view file at `app/views/<resource>/<action>.turbo_stream.erb`. So for my `TodosController#toggle_priority` action, the view lives at `app/views/todos/toggle_priority.turbo_stream.erb`. The contents of that view are usually just one line - for me it's:

```erb
<%= turbo_stream.replace @todo, partial: "todos/todo", locals: { todo: @todo } %>
```

That helper builds the `<turbo-stream action="replace" target="...">` HTML automatically and re-renders the `_todo.html.erb` partial to fill in the new content. Easy.

The last piece is on the client side: the browser only knows to send `Accept: text/vnd.turbo-stream.html` (which tells the server "I want a stream back") if the form or link opted in. With `button_to` you do that by adding `data: { turbo_stream: true }` to the form's data attributes. If you don't opt in, the same action still works - Rails falls back to the `format.html` branch, the browser does a full reload, and the world keeps spinning. That's why I added a `format.html { redirect_to todos_path }` branch as a fallback: if someone hits the endpoint with `curl` or with JavaScript disabled, the toggle still flips and they get a normal page back.

**What I double-checked.** Claude told me the MIME type is `text/vnd.turbo-stream.html` and the view file for my action goes at `app/views/todos/toggle_priority.turbo_stream.erb`. I went and checked both against the actual sources:

- The MIME type really is registered in [`turbo-rails/lib/turbo/engine.rb`](https://github.com/hotwired/turbo-rails/blob/main/lib/turbo/engine.rb) - the file literally calls `Mime::Type.register "text/vnd.turbo-stream.html", :turbo_stream`. So Claude wasn't making it up. 
- The view path is just Rails' normal template lookup rule: `<controller name>/<action name>.<format>.<handler>` (handler being `erb`). So `todos/toggle_priority.turbo_stream.erb` is exactly the right path. 
- The [Turbo handbook on Streams](https://turbo.hotwired.dev/handbook/streams) confirmed the seven actions and the `<turbo-stream>` element format are what Claude described. 

**Self-check (no peeking):** MIME type is `text/vnd.turbo-stream.html`; the view for `TodosController#toggle_priority` goes at `app/views/todos/toggle_priority.turbo_stream.erb`.

### Acceptance criteria (my words)

> **As a** user of the todo list **I want to** mark any single todo as "high priority" with one click **so that** I can spot the rows I care about without leaving the index page.

- `Todo` has a `high_priority:boolean` column, non-null, default `false`.
- Every row on the index has a toggle button showing the current state (* vs o).
- Clicking it sends `PATCH /todos/:id/toggle_priority`. With `Accept: text/vnd.turbo-stream.html` the server responds with `Content-Type: text/vnd.turbo-stream.html` and a `<turbo-stream action="replace">` for just that row. The rest of the page doesn't rerender.
- A plain `PATCH` (no Turbo) still works and redirects to the index.
- At least one test asserts the media type, the action, and the target.

### Final plan (after my edits)

1. **Slice A - data.** Migration `AddHighPriorityToTodos` with `high_priority:boolean, default: false, null: false`. Run `bin/rails db:migrate`. No model changes - it's just a flag.
2. **Slice B - route + controller.** Add `member { patch :toggle_priority }` under `resources :todos`. Add `TodosController#toggle_priority` that flips the boolean with `update!` and responds with `format.turbo_stream` plus `format.html { redirect_to todos_path, status: :see_other }` as a no-JS fallback. Add `:toggle_priority` to the `set_todo` before-action list. Do **not** add `:high_priority` to `todo_params`.
3. **Slice C - view + test.** `button_to` in `app/views/todos/_todo.html.erb` posting to `toggle_priority_todo_path(todo)` with `data: { turbo_stream: true }`. New `app/views/todos/toggle_priority.turbo_stream.erb` with `turbo_stream.replace @todo, partial: "todos/todo"`. Update `test/fixtures/todos.yml` so the two fixtures have different priorities. Add a controller test that PATCHes with the Turbo `Accept` header and asserts media type, `action="replace"`, and the right target id.

### Commits

| Slice | Commit | Subject |
| --- | --- | --- |
| A | [`380559a`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/commit/380559a) | Add high_priority boolean to todos |
| B | [`42edf7e`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/commit/42edf7e) | Add toggle_priority member action for todos |
| C | [`547524f`](https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/commit/547524f) | Add Turbo-Stream toggle UI for high_priority |

### Tests

```
$ bin/rails test test/controllers/todos_controller_test.rb
Running 8 tests in a single process (parallelization threshold is 50)
Run options: --seed 22553

# Running:

........

Finished in 0.163816s, 48.8353 runs/s, 115.9838 assertions/s.
8 runs, 19 assertions, 0 failures, 0 errors, 0 skips
```

The new test (`toggle_priority flips high_priority and responds with a Turbo Stream`) fails on `main` (no route / no action / no view) and passes on `hw5`.

### Browser verification

I'm running Claude Code in a headless setup so I couldn't open a real Chrome tab and stare at the Network panel. But the things the homework asks me to check in DevTools - the request header, the response Content-Type, and that the page doesn't fully reload - are exactly the things I'm checking inside the controller test. Here's how they line up:

- **Request `Accept` header is `text/vnd.turbo-stream.html`** -> the test sets `headers: { "Accept" => "text/vnd.turbo-stream.html" }` when it calls `patch`. That's the same header Turbo sends from the browser when a form opts in with `data-turbo-stream`.
- **Response `Content-Type` is `text/vnd.turbo-stream.html`** -> the test asserts `response.media_type == "text/vnd.turbo-stream.html"`. Same value DevTools would show.
- **Page doesn't reload** -> I can't watch the network tab from a test, but I can prove the structural reason a reload doesn't happen: the response body is a `<turbo-stream action="replace" target="todo_<id>">` snippet, not a full HTML document. The test asserts both the `action="replace"` and the specific target id, so if a future change accidentally goes back to redirecting (which would full-reload the page), the test fails.

### Things I rejected from the AI

- **Adding `:high_priority` to strong params.** Claude wanted to whitelist `high_priority` in `todo_params` so the regular edit form could also flip it. I said no. The whole point of having a dedicated `toggle_priority` action is that there's exactly one way to flip the flag. If I also allow it through the form, now there are two places that can change the priority, and any future bug in either path applies to both. Less surface area = fewer ways to mess up. Dropped it.
- **System test vs. controller test.** Claude proposed a Capybara system test that visits the page, clicks the star, and asserts the star icon changed. The problem is, that test would also pass if the toggle did a full page reload - Capybara just sees the new DOM, it doesn't care how it got there. But the homework specifically wants me to prove the response is a Turbo Stream and not a full HTML page. So I replaced it with a controller test that asserts the response's MIME type and inspects the actual `<turbo-stream>` tags in the body. That test fails if anything regresses to plain HTML, which is what I actually want to catch.

---

## PR

- <https://github.com/NU-CS-Software-Studio-Spring-26/homework-5-andrewhxd/pull/1> - opened from `hw5` to `main`, then closed without merging per the homework instructions.
