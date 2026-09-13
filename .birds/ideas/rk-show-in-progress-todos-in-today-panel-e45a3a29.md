---
id: rk-show-in-progress-todos-in-today-panel-e45a3a29
short-id: e45
title: 'Show in-progress todos in #today-panel'
priority: 4
labels:
- fix-today-panel-in-progress
- feat-todos-in-progress
deps: []
closed: true
---
A todo marked `status: "in-progress"` (or its shorthand `active: true`) is the thing
the author is working on RIGHT NOW. `#today-panel` drops it off the day view unless
its date or its priority happens to qualify it by some other route — so the one todo
you are certainly going to touch today is the one the day view is most likely to hide.

A todo being worked on is on for today by definition. That is the bug.

Touches: todos/0.1.0/src/today.typ, todos/0.1.0/test/units.typ, todos/0.1.0/demo/rheo/content/index.typ, todos/0.1.0/demo/rheo/check.sh, todos/0.1.0/readme.md

## Where it is, exactly

`/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ:36-43` is the whole of the
selection:

```typ
#let _on-today(row, today: none, horizon: 0, overdue: true, top: none, also: none) = {
  let t = row.tags-dict
  ((also != none and also(row))
    or is-upcoming(t, today: today, within: horizon)
    or (overdue and is-overdue(t, today: today))
    or is-scheduled-now(t, today: today)
    or (top != none and row.priority >= top))
}
```

Five ORed clauses — a caller-supplied `also:` predicate, a deadline landing within
`horizon:` days, an overdue deadline, a scheduled date that has arrived, and a
priority at or above the `top` band. None of them is "in progress". `today-panel`
applies it at `today.typ:133`, and a row that satisfies none of the five never
reaches `#todo-table` at all.

**The ordering half is already done — do not redo it.**
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ:144-151`:

```typ
#let _sort-key(state, when, order) = {
  let newest = order == "newest"
  let lead = if state == "in-progress" {
    if newest { "1" } else { "0" }
  } else if newest { "0" } else { "1" }
  lead + (if when == none { "\u{ffff}" } else { when })
}
```

That leading character hoists an in-progress row above every date, and
`#today-panel` inherits it whole because it renders through `#todo-table` and draws
nothing of its own. So once the row is SELECTED it already arrives at the top. This
bird is a selection fix only; it changes no sort, no CSS, and no rendering.

**The predicate to test is `row.status == "in-progress"`,** a plain top-level field
on a `todos()` row. That is exactly what `_state-of` tests at `table.typ:130`, so
this bird introduces no new notion of what "in progress" means. `active: true` is
resolved to `status: "in-progress"` upstream in `src/tags.typ:201`, so testing
`status` covers the shorthand for free — do NOT test `active` separately.

## Steps

1. **Add a sixth clause to `_on-today`** in `src/today.typ:36-43`:

   ```typ
   or row.status == "in-progress"
   ```

   Put it FIRST in the OR chain, immediately after the `also:` clause. It is the
   cheapest test in the list — one string comparison against a field already on the
   row, where every other clause calls into `@rookery/timeline` with a tags
   dictionary — and Typst's `or` short-circuits.

2. **Take no new argument for it.** Every other clause has a knob (`horizon:`,
   `overdue:`, `priority:`, `also:`) and this one deliberately does not. `overdue:
   false` exists because a site may log lapsed work somewhere else; there is no
   coherent site that wants its day view to hide what its author has declared they
   are working on right now. Unconditional is also what makes the rule explainable
   in one line in the readme. Do not add `in-progress: true` or `active: true` to
   `today-panel`'s signature.

3. **`filter:` still applies first, and must keep applying first.** `today.typ:127-128`
   narrows the corpus before the day's question is asked, defaulting to dropping
   closed rows. A closed todo that still carries `status: "in-progress"` therefore
   stays off the panel, which is correct — it is not outstanding work. Do not move
   the new clause anywhere that would bypass `filter:`.

4. **Update the two comments that now state a wrong number.**
   - `src/today.typ:29-35`, the comment above `_on-today`, opens "IS THIS ROW ON FOR
     TODAY. Five independent reasons, ORed together" and then lists them. Make it six
     and name the new one — that a todo declared in progress is on for today whatever
     its dates say.
   - `src/today.typ:1-10`, the file header, describes the question this file answers
     as "what is on for today, and what is the most important thing outstanding
     regardless of its date". Extend it to cover what is being worked on regardless of
     its date.

   Follow this repo's comment rule from `/home/lox/code/_fcl/rookery/CLAUDE.md`:
   describe the code as it stands, present tense, no history, no issue ids, no note
   that a clause was added or that the count used to be five.

5. **Fix the test fixture before adding assertions, or every existing one panics.**
   `test/units.typ:484` is:

   ```typ
   #let dayrow(priority: 0, tags: (:)) = (tags-dict: tags, priority: priority)
   ```

   It builds a row with NO `status` key. The moment `_on-today` reads `row.status`,
   all fifteen or so existing `_on-today` assertions at `test/units.typ:487-548`
   fail the compile with `dictionary does not contain key "status"`. Extend the
   fixture:

   ```typ
   #let dayrow(priority: 0, status: none, tags: (:)) = (
     tags-dict: tags, priority: priority, status: status,
   )
   ```

   Fix it in the fixture rather than making `_on-today` read
   `row.at("status", default: none)`. A real `todos()` row always carries `status` —
   `_state-of` at `table.typ:130` reads it unguarded on production rows — so a
   defensive read in `_on-today` would be papering over an artificial fixture, and
   would hide a genuinely malformed row instead of failing on it.

6. **Add assertions** beside the existing `_on-today` block in `test/units.typ`
   (the section opens at line 471):

   - An in-progress row with no dates and no priority is on today:
     `_on-today(dayrow(status: "in-progress"), today: NOW)` is `true`.
   - The same row with `status: none` is not:
     `_on-today(dayrow(), today: NOW)` is `false`. (`test/units.typ:548` already
     asserts this shape for `also: none`; the new one is about `status`.)
   - An in-progress row whose deadline is far in the future still qualifies — use a
     deadline outside the horizon, in the shape `test/units.typ:492` already uses.
   - An in-progress row is unaffected by `overdue: false` and by `priority: none`
     (pass `top: none`), so the new clause is genuinely independent of the others.
   - A row with some other status (`"deferred"`, say — `src/tags.typ:50` lists the
     three) is NOT on today by virtue of its status.

7. **Give the demo a todo that only the new clause can select.** The demo project has
   no in-progress todo at all today — `rg -n 'active:|status:' demo/rheo/content/index.typ`
   returns nothing — so it neither breaks nor exercises this change as it stands.

   Add one to `demo/rheo/content/index.typ`, near the other day-view cases around
   lines 95-115, following the shape already there:

   ```typ
   #todo(
     "migrate",
     title: [Migrate the datastore],
     active: true,
     tags: entries(deadline: datetime(year: 2026, month: 10, day: 30)),
   )[Being worked on now, due at the end of next month.]
   ```

   It must have NO priority (so the priority band cannot pick it up), NO scheduled
   date, and a deadline far enough out that neither `is-upcoming` at `horizon: 0` nor
   `is-overdue` fires. The demo's `TODAY` is 2026-08-25 — `renew` at
   `demo/rheo/content/index.typ:106-111` is the "due exactly today" case and carries
   that date. A deadline in October is safely outside every other clause, so this row
   reaches the panel through the new clause or not at all.

   Write a line of prose above it, as every other todo in that file has, saying that
   a todo being worked on is on today's list whatever its dates say.

8. **Extend the demo's assertion.** `demo/rheo/check.sh:222` currently reads:

   ```python
   want = {"mirror", "invoice", "renew", "ship"}
   ```

   Add `"migrate"` to that set, and extend the failure message just below it (lines
   223-226), which enumerates why each member is there, with the new reason — the
   in-progress one. That message is the thing a future reader debugs from, so leaving
   it listing four reasons for five rows is worse than not touching it.

9. **Update the readme.** `todos/0.1.0/readme.md:533-595` documents this view. Line
   541 says it "lists the union of four things" and then names them. Make it five and
   name the new one. Add a short bold paragraph in the same style as the existing
   **Overdue work stays on the list by default.** one — say that a todo marked
   `status: "in-progress"` (or `active: true`) is always listed and always sorts
   above every dated row, that this is the one clause with no argument to turn it
   off, and why.

## Non-goals

- **Do not touch `_sort-key` or anything else in `src/table.typ`.** The hoist already
  works and is shared with `#todo-table`; this is a selection fix.
- **Do not reorder `_state-of`** (`table.typ:127-133`). It tests `is-blocked` before
  `in-progress`, so a todo that is both blocked AND in progress derives the state
  `"blocked"` and therefore does not get the sort hoist — though the new clause DOES
  still select it onto the panel. That ranking is deliberate (see the comment at
  `table.typ:61-64`). Leave it alone and do not file it as part of this bird; if it
  turns out to matter, it is its own change.
- **No new argument on `today-panel`** — see step 2.
- **No change to `#todo-table`'s own selection.** It already lists everything open.
- **No change to `src/tags.typ`**, `active:`, or what `"in-progress"` means.
- **No CSS change.** The green wash for in-progress rows already exists.
- **Do not touch any other package.**

## VERIFY

Run from `/home/lox/code/_fcl/rookery/todos/0.1.0`:

1. `just test` passes — the Typst unit fixture compiles, which means every existing
   `_on-today` assertion still holds and the new ones do too. A failure prints a line
   number.
2. `just test-js` passes, unchanged.
3. `just check` passes: the demo compiles and `check.sh` exits zero, with the
   today-panel line now printing `['invoice', 'migrate', 'mirror', 'renew', 'ship']`.
4. Confirm the fix is load-bearing rather than incidental: temporarily change
   `migrate`'s `active: true` to `active: false` in
   `demo/rheo/content/index.typ`, run `just check`, and confirm it FAILS with the
   today-panel mismatch. Restore `active: true` and confirm it passes again.
5. `rg -n 'in-progress' src/today.typ` finds the new clause and the updated comment.
6. `rg -n 'Five independent reasons' src/today.typ` returns nothing.