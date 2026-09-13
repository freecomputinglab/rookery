---
id: rk-add-active-true-as-a-status-shorthand-2a7f6a1e
short-id: 2a7
title: 'Add active: true as a status shorthand'
priority: 3
labels:
- feat-todos-in-progress
deps:
- blocked-by:rk-hoist-in-progress-todos-to-the-top-d3a08506
closed: false
---
Marking a todo as being worked on costs a quoted string today —
`#todo("x", status: "in-progress")` — where closing one costs a named argument,
`done: d`. Add `active: true` as the shorthand for `status: "in-progress"`, the
same way `done:` is the shorthand for `timeline: (closed: ..)`.

**It does not exist yet.** `rg -n '\bactive\b'` over
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/*.typ` and its `readme.md` returns
nothing; the only nearby name is the log stage `ACTIVATED-STAGE`
(`src/tags.typ:61`), which is a different thing and stays untouched — see the
decisions below.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/src/todo.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/readme.md

## What exists now

- `#todo` (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/todo.typ:125`) takes
  `status: none` at line 128 and forwards it into `todo-tags` as
  `status: status,` at line 144.
- `todo-tags` (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ:148`) takes
  `status: none` at line 152 and, in the block at lines 180-189, asserts the
  value is in `STATUSES` (`tags.typ:50`, which is
  `("in-progress", "deferred", "draft")`) and inserts the flat key
  `"todo-" + status`.
- `todo-tags` is exported through `src/lib.typ:20` and is directly unit-tested:
  `test/units.typ:23` already asserts
  `todo-tags(status: "in-progress").keys() == ("todo", "todo-in-progress")`.

## Decisions already made — do not re-derive

- **Resolve `active:` inside `todo-tags`, not inside `#todo`.** `todo-tags` is
  the exported, directly-testable function that owns every one of this package's
  keys, and putting the synonym there means a caller reaching `todo-tags`
  directly gets it too. `#todo` only grows the parameter and forwards it.
- **`active:` is a BOOL, where `done:` is a date, and that asymmetry is correct.**
  A close is a dated EVENT and lives in the log, which is why `done: true` is
  refused (`src/todo.typ:95-104`). Being under way is a STATE — the flat
  `todo-in-progress` key — and `status: "in-progress"` has never carried a date.
  There is no clock to stamp one from anyway (`datetime.today()` returns
  1980-01-01 under a reproducible build). So `active:` takes `true` or `false`
  and nothing else.
- **Do NOT write an `activated` log entry from `active:`.** `ACTIVATED-STAGE`
  (`src/tags.typ:61`) is a dated stage on `TODO-LADDER` and the comment above it
  states the split outright: the flat key is what a tag query filters on, the log
  entry is what says SINCE WHEN. A boolean cannot supply a date, and synthesising
  one would put a false date in the log. A caller wanting both writes
  `#todo("x", active: true, timeline: (activated: d))`, and that must keep
  working.
- **`active: false` emits nothing**, exactly as `closed: false` does
  (`src/tags.typ:143-147` explains why): absence means "not said", not "not in
  progress". A `todo-in-progress` key valued `false` would mark every open todo
  as in progress to any consumer testing for the key.
- **Refuse `active: true` together with any non-`none` `status:`**, even when the
  status IS `"in-progress"`. Two spellings of one field on one call is a
  contradiction to report rather than a merge to perform — the same reading
  `_closing` takes of a close written twice (`src/todo.typ:112-119`). One write
  path, one message.
- **Use a NEW local name in `todo-tags` rather than shadowing the `status`
  parameter.** `#let status = if active { .. } else { status }` reads the
  parameter on its own right-hand side, which is a Typst question this bird has
  no reason to open. Bind `st` and use it in the block below.
- **Nothing downstream changes.** `_state-of` (`src/table.typ:127-133`) reads
  `row.status`, `status-of` (`src/tags.typ:284`) reads the flat key, and both see
  exactly what `status: "in-progress"` already produces. The `#done(date)` and
  `#epic(name)` factories, and a site's own `#let todo = todo.with(..)`, are all
  `.with` over `#todo` and inherit the new parameter for free.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Steps

1. In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ`, add a parameter to
   `todo-tags`. The list currently reads (lines 148-157) `#let todo-tags(` /
   `tags: none,` / `priority: none,` / `kind: none,` / `status: none,` then the
   two-line comment above `closed: false,`. Insert immediately after
   `  status: none,`:

   ```typ
     // `true` IS THE SHORTHAND for `status: "in-progress"`, resolved below so that
     // everything downstream reads one field. A BOOL, where `done:` is a date:
     // a close is a dated event and lives in the log, while being under way is a
     // state and never carried a date. `false` emits nothing, like `closed:` below.
     active: false,
   ```

2. In the same file, replace the whole `if status != none { .. }` block at lines
   180-189 with the following, which validates `active:`, refuses the two
   spellings together, and resolves them into one local:

   ```typ
     assert(
       type(active) == bool,
       message: "@rookery/todos: `active` is a flag, `true` or `false` — got "
         + repr(active) + ". It is the shorthand for `status: \"in-progress\"`, and "
         + "carries no date: a todo recording WHEN it was picked up writes "
         + "`timeline: (activated: ..)` alongside it.",
     )
     // TWO SPELLINGS OF ONE FIELD ON ONE CALL is a contradiction to report rather
     // than a merge to perform — the same reading `_closing` takes of a close
     // written twice. Refused even where the two agree, so there stays one write path.
     assert(
       not (active and status != none),
       message: "@rookery/todos: this todo says how far along it is twice — once as "
         + "`active: true` and once as `status: " + repr(status) + "`. They are the "
         + "same field, so write one of them.",
     )
     let st = if active { "in-progress" } else { status }

     if st != none {
       assert(
         st in STATUSES,
         message: "@rookery/todos: `status` must be one of "
           + STATUSES.join(", ") + " — got " + repr(st)
           + ". A CLOSED todo is expressed by `done:`, not by `status:`, and a "
           + "BLOCKED one is derived from its dependencies rather than declared.",
       )
       out.insert("todo-" + st, none)
     }
   ```

3. In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/todo.typ`, add `active: false,`
   to `#todo`'s parameter list immediately after `  status: none,` (line 128).

4. In the same file, in the `todo-tags(` call inside `#todo`, add
   `      active: active,` on the line immediately after
   `      status: status,` (line 144).

5. Add to `/home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ`, immediately
   after the existing line 23
   (`#assert.eq(todo-tags(status: "in-progress").keys(), ("todo", "todo-in-progress"))`):

   ```typ
   // `active: true` is the same claim in fewer characters, and resolves to the
   // same key rather than to one of its own.
   #assert.eq(todo-tags(active: true).keys(), ("todo", "todo-in-progress"))
   // `false` is the default and says nothing, like `closed: false`.
   #assert.eq(todo-tags(active: false).keys(), ("todo",))
   #assert.eq(todo-tags().keys(), ("todo",))
   ```

   Do NOT add asserts for the two panics here. `units.typ` is a compile-and-pass
   fixture: an `assert` that fires fails the whole compile, so a test that
   EXPECTS a panic cannot live in it. `test/panics.sh` is where this package
   tests refusals; adding a case there is out of scope for this bird.

6. In `/home/lox/code/_fcl/rookery/todos/0.1.0/readme.md`, document the
   shorthand. Insert a section immediately before the line
   `## 0.1.0 — a todo's dates are one log` (line 77):

   ```markdown
   ## Marking a todo in progress

   Two spellings, one key — `active:` folds into `status:` before anything reads
   it, so they cannot disagree:

   ```typst
   #todo("fetch", status: "in-progress")[...]   // the field, written directly
   #todo("fetch", active: true)[...]            // the shorthand
   ```

   - **`active:` is a FLAG, not a date**, where `done:` is the other way round. A
     close is a dated event and belongs in the log; being under way is a state,
     and `status: "in-progress"` never carried a date. A todo that wants to record
     when it was picked up writes the log stage that exists for it alongside:
     `#todo("fetch", active: true, timeline: (activated: d))`.
   - **`active: false` is the default and emits nothing.** Absence is "not said",
     not "not in progress" — the same rule `closed: false` follows.
   - **Both at once is refused.** `active: true` together with any `status:` is
     one field written twice, so write one of them.
   ```

   Then update the status row of the flat-tag table at line 173, which currently
   reads:

   ```markdown
   | `todo-in-progress`, `todo-deferred`, `todo-draft` | `status:` |
   ```

   to:

   ```markdown
   | `todo-in-progress`, `todo-deferred`, `todo-draft` | `status:` (or `active:` for the first) |
   ```

## Do NOT

- Do not add a date, a log entry or an `activated` stage from `active:`. See the
  decisions above.
- Do not touch `ACTIVATED-STAGE`, `TODO-LADDER`, `STATUSES` or any other constant
  in `src/tags.typ:40-75`.
- Do not add a matching `deferred:` or `draft:` shorthand. Only the one asked for.
- Do not touch `src/table.typ`, `src/today.typ`, `src/views.typ`, `src/todos.css`
  or any `.js` file — nothing downstream reads `active:`, and two other birds are
  changing the order and the colour of in-progress rows.
- Do not add a panic case to `test/panics.sh`.
- Do not edit `src/todo.typ`'s `_closing`, the `done:` argument, or any of its
  assertions.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

Expected: `just test` compiles `test/units.typ` without a panic, runs
`test/panics.sh`, and prints `units OK`. The three new asserts are the decisive
part — `todo-tags(active: true)` producing anything other than
`("todo", "todo-in-progress")` fails the compile with a line number.

Then confirm the two refusals fire, by compiling a one-line fixture that should
NOT compile:

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && printf '#import "/src/lib.typ": *\n#let _ = todo-tags(active: true, status: "draft")\n' > /tmp/active-clash.typ && typst compile --features html --root . --format pdf /tmp/active-clash.typ /dev/null
```

Expected: it FAILS, with the message `says how far along it is twice`. A clean
compile here means the assertion was not reached and step 2 is wrong.

No separate `just build` is needed: `typst.toml`'s `entrypoint` points at
`src/lib.typ`, so a Typst edit takes effect immediately, and `dist/` holds only
the JavaScript bundle this bird does not touch. (The `build` recipe's comment in
the `Justfile` claims otherwise; it is stale.)