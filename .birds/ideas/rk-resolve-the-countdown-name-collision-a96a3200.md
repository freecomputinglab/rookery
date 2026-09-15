---
id: rk-resolve-the-countdown-name-collision-a96a3200
short-id: a9
title: Resolve the countdown name collision
priority: 3
labels:
- chore-timeline-api
deps: []
closed: false
---
`countdown` is both a function (`timeline/0.1.0/src/when.typ:190`) and a flag on
`#upcoming` (`timeline/0.1.0/src/upcoming.typ:315`). A parameter and a
module-level function of the same name cannot both be reachable by that name
inside a function body, so the function is unreachable wherever the flag exists —
and two packages have paid for it with an aliased second import of the same
module:

- `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ:45-49` imports
  `when.typ` twice, once starred and once `as _when`, with a comment explaining
  the collision.
- `/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ:30-36` does the same to
  `@rookery/timeline` itself, for the same reason, and says so.

Rename the flag. It is the smaller break of the two (a keyword argument on two
views, against a function four files call), and it reads better anyway: the flag
turns a chip ON, which is what `show-` prefixes mean everywhere else in this
family (`#idea(show-date:, show-tags:, show-frame:, show-id:)`).

While the function is open: both call sites build its CSS tag by hand as
`"due-" + c.level` (`upcoming.typ:414` and the badge block in
`todos/0.1.0/src/table.typ`). One tag, two places that spell it.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/readme.md
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/test/units.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/test/upcoming.typ
Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ

## Steps

1. In `timeline/0.1.0/src/upcoming.typ`, rename the `countdown: false` parameter
   to `show-countdown: false` on `#upcoming` (line 304). `#upcoming-rows` (209)
   does not take it and must not gain it — it ships `in-days` on every row
   unconditionally, which is the documented split.
2. Delete the `#import "when.typ" as _when` at line 49 and its explanatory
   comment, and change the two `_when.countdown(..)` calls (lines ~355 and ~414)
   to plain `countdown(..)`.
3. In `timeline/0.1.0/src/when.typ`, have `countdown` return the CSS tag beside
   the level: `(text: .., level: .., tag: "due-" + level)`. Keep `level` — the
   three bands are the meaningful thing and a caller may want to branch on them
   without parsing a class name.
4. Use it at `upcoming.typ:414`: `bs.push((text: c.text, tag: c.tag))`.
5. In `todos/0.1.0/src/table.typ`, delete the
   `#import "@rookery/timeline:0.1.0" as _tl` at line 36 and its comment, add
   `countdown` and `days-until` to the starred import at line 31, and replace the
   `_tl.countdown(..)`/`_tl.days-until(..)` calls and the hand-built `"due-" + ..`
   tag with the plain names and `c.tag`. If `#todo-table` has its own parameter
   named `countdown`, rename that to `show-countdown` too — the whole point is
   that no file in this repo has both names live at once.
6. `todos/0.1.0/src/skin.typ:20` also imports timeline `as _tl`, for `window`
   rather than for `countdown`. Leave that one alone.
7. Update `timeline/0.1.0/test/upcoming.typ` (the `countdown:` call site) and the
   `countdown` assertions in `timeline/0.1.0/test/units.typ` to cover `tag`.
8. Update `timeline/0.1.0/readme.md` and `todos/0.1.0/readme.md` wherever they
   name the `countdown:` flag.

## Non-goals

- **Do not rename the function.** `countdown(days)` is the name four files
  already import and the readmes document; the flag is what moves.
- **Do not change the bands or the cutoffs.** Three bands, fixed at 7 and 14.
- **Do not change the class names in the stylesheet** — the chips still wear
  `idea-tag-due-urgent`/`-soon`/`-later`, which is what a project themes through
  rookery's `tags-color`.
- **Do not touch `skin.typ`'s `_tl` alias**, which exists for a different
  collision.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test` — `units OK`,
   `views OK`. The view check already asserts the chip is LAST in the badge strip
   and that the default draws none, so a broken rename fails there rather than
   quietly.
2. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check` passes.
3. `rg -n 'as _when|as _tl' /home/lox/code/_fcl/rookery/timeline
   /home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ` returns nothing.
4. `rg -n '"due-" \+' /home/lox/code/_fcl/rookery` returns only `when.typ`.