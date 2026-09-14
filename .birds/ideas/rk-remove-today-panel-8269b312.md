---
id: rk-remove-today-panel-8269b312
short-id: '8269'
title: Remove today-panel
priority: 3
labels:
- feat-todo-band-order
deps:
- blocked-by:rk-filter-todo-table-by-band-67fc9bfb
closed: false
---
`#todo-table(bands: (0,))` now answers the question `#today-panel` was built to
answer, so the day view is a second implementation of the panel's own top band.
Remove it.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/src/lib.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css, /home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/readme.md, /home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/content/index.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/check.sh, /home/lox/code/_fcl/rookery/cfps/0.1.0/readme.md, /home/lox/code/_fcl/rookery/cfps/0.1.0/test/units.typ

## What replaces what

`#todo-table` takes a `bands:` parameter. `bands: (0,)` lists only its top
band: a row that is overdue, due today, due tomorrow, at the hottest priority
among the rows the panel lists, in progress, or named by the panel's `hoist:`
predicate. That is the six reasons `_on-today`
(`/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ` lines 38-46) ORs
together, one for one:

| `_on-today` clause | band 0 equivalent |
|---|---|
| `row.status == "in-progress"` | `_band` returns 0 for an in-progress row |
| `is-upcoming(.., within: horizon)` | the `urgent` countdown band |
| `overdue and is-overdue(..)` | the `urgent` countdown band |
| `is-scheduled-now(..)` | a scheduled date already arrived is `urgent` |
| `top != none and row.priority >= top` | rung 0 on the panel's own priority scale |
| `also(row)` | the panel's `hoist:` predicate |

Two differences, both deliberate, and both worth stating in the landing
message:

- **Band 0 includes tomorrow.** `#today-panel`'s `horizon: 0` default meant
  today exactly. A deadline landing tomorrow is `urgent` to
  `@rookery/timeline`'s `countdown()`, so it is band 0 now. A widening.
- **`horizon:` and `priority: auto|int|none` do not survive.** A caller who
  wants a two-day horizon wants `bands: (0, 1)`, which is a wider net than two
  days; a caller who wanted the priority half switched off has no equivalent.
  Neither knob has a consumer in this repo.

## What to do

1. Delete `/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ` outright.
   It holds `_top-priority`, `_on-today` and `#today-panel`, and nothing else.

2. In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/lib.typ`, delete lines
   31-33 — the two-line comment beginning "AFTER `table.typ`, whose
   `#todo-table` it projects into a day view" and the
   `#import "today.typ": *` beneath it. Leave every other import and its
   comment untouched: the file's header (lines 14-17) states that the import
   order is load-bearing because a Typst closure captures the scope visible at
   definition time, and removing one line from the middle does not disturb the
   rest.

3. In `/home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ`, delete the
   `_top-priority` / `_on-today` block: the section header at line 471
   (`// ---- _top-priority / _on-today — #today-panel's pure selection ---`),
   every assertion and fixture down to and including line 544, and the orphan
   `_on-today` assertion that sits alone at line 573 after the `_sort-key`
   block. The `dayrow` fixture at lines 485-489 goes with them — check with
   `rg -n 'dayrow' test/units.typ` that nothing else uses it before deleting,
   and if something does, keep the fixture and delete only the assertions.

4. In `/home/lox/code/_fcl/rookery/todos/0.1.0/readme.md`, delete the whole
   `## A day view: #today-panel` section — line 533 through the last line
   before the next header, `## Decks: #todo-slipshow` at line 603. Then fix
   line 451, which reads `... keeps tags off the row entirely; #today-panel`
   — rewrite that clause to name the `badge-pills: true` argument instead of
   the removed function. Do not add a "this was removed" note anywhere: this
   repo's `CLAUDE.md` lines 66-98 forbid documenting what is gone.

5. In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ` line 296, the
   `badge-pills:` doc comment says "ON BY DEFAULT in `#today-panel`, where a
   handful of rows are read whole rather than scrolled, so the grid-width cost
   above does not apply." Rewrite it so the argument survives without the
   name: a day view — `bands: (0,)` — is a handful of rows read whole rather
   than scrolled, which is where turning this on is worth the grid width.

6. In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css`, fix the two
   comment mentions at lines 198 and 220. Line 198 reads "BOTH LIST SHAPES.
   `#todo-table` and `#today-panel` build rows through `#panel`" — there is one
   list shape now, so say that. Line 220 attributes a rule to
   "`#today-panel`'s `badge-pills: true`" — attribute it to `badge-pills: true`.
   **No CSS rule changes**, only comments.

7. In `/home/lox/code/_fcl/rookery/cfps/0.1.0/readme.md`, fix the two prose
   mentions at lines 133 and 138, replacing `#today-panel` with `#todo-table`
   in both — the claim each one makes (an open call shows up in a consumer's
   worklists with no separate wiring) is unchanged.

8. In `/home/lox/code/_fcl/rookery/cfps/0.1.0/test/units.typ` line 103, a
   comment says "everything built on it, like a consumer's `today-panel`".
   Rewrite to name `todo-table`. Comment only; no assertion changes.

## The demo, and its browser suite

9. In `/home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/content/index.typ`:

   - Line 7 lists `today-panel` in the import list. Remove that name.
   - The section at lines 256-267 is headed `== Today — \`#today-panel\`` and
     ends with `#today-panel(today: TODAY, noun: "todos")`. Rewrite the header
     as `== Today — \`bands: (0,)\`` and the call as:

     ```typ
     #todo-table(today: TODAY, bands: (0,), badge-pills: true, visible: none, noun: "todos")
     ```

     Keep the narration at lines 258-265 — the claims it makes about `renew`,
     `invoice`, `mirror`, `ship` and `retro` still hold — but replace the
     sentence naming the function, and add that a deadline landing tomorrow
     reads in this band too.
   - Lines 85 and 103 each name `#today-panel` inside narration about other
     todos ("still `#today-panel`'s problem for as long as this stays open",
     "the boundary `#today-panel`'s default"). Rewrite both to name the top
     band rather than the removed function. Line 103's claim is about the
     today-exactly boundary and is no longer the boundary — band 0 reaches
     tomorrow — so correct the fact, not just the name.

10. `/home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/check.sh` asserts on the
    built markup and has two blocks that name the day view:

    - **Lines 202-234**, the selection check. It locates its section with
      `i = h.index("Today —")` and asserts the row set is exactly
      `{"mirror", "invoice", "renew", "ship", "migrate"}`, with `retro`
      explicitly absent. The `h.index("Today —")` anchor still works if you
      keep `== Today —` as the header prefix in step 9, which is why that
      header keeps its first two words. Update the `want` set only if the
      corpus actually produces a different one — a todo dated exactly tomorrow
      would now join, and you must check
      `demo/rheo/content/index.typ` for one rather than assume. Rewrite the
      block's explanatory comment so it no longer names `#today-panel`.
    - **Lines 235-283**, the `badge-pills:` check, whose whole claim is that
      the knob is OFF on one list and ON on the other. The contrast is now
      between two `#todo-table` calls, one of which passes
      `badge-pills: true`. Keep both halves of the assertion and rewrite the
      comments and the `note(..)` strings so they name the argument rather
      than the function.

## Non-goals

- **Do not leave a deprecation shim.** No `#let today-panel(..) = todo-table(bands: (0,), ..)`.
  The one consumer outside this repo is
  `/home/lox/code/waterline/rookery/index.typ`, which a separate bird in that
  repo updates. This package's `typst.toml` pins `0.1.0` and the consuming
  site tracks that branch by path, so there is no published version to keep
  compatible.
- **Do not change `#todo-table`'s behaviour.** Everything this bird touches in
  `table.typ` and `todos.css` is a comment.
- Do not restructure `readme.md` beyond deleting the one section and fixing
  the one clause at line 451.
- Do not touch `/home/lox/code/waterline`.
- Do not add a `bands:` pill group, a band CSS class, or a `tiers:` alias.

## Comment style

This repo's `CLAUDE.md` lines 66-98 are the rule that decides how every
comment in this bird gets rewritten: **describe the present**. Never "used to
live in `today.typ`", never "replaces `#today-panel`", never "the day view was
removed". A reader arriving cold needs the current shape and the reasons it
holds. No bird ids, no branch names.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/todos/0.1.0`:

1. `rg -n 'today-panel|today\.typ|_on-today|_top-priority' /home/lox/code/_fcl/rookery`
   returns nothing outside `.birds/`.

2. `just test` — `typst compile --features html --root . --format pdf test/units.typ /dev/null && ./test/panics.sh`. Must pass.

3. `just test-js` — `node --test test/*.test.mjs`. Must pass unchanged.

4. `just check` — `rheo compile demo/rheo && ./demo/rheo/check.sh`. Must pass,
   including both rewritten blocks. This is the assertion that matters most:
   it proves `bands: (0,)` selects the same five demo rows the day view did.

5. From `/home/lox/code/_fcl/rookery`, `just build` — the root recipe walks
   every nested Justfile, which is how the `cfps` package's own suite runs
   after its readme and test comments change.