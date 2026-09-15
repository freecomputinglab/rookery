---
id: rk-collapse-the-three-day-stamp-helpers-f7663c69
short-id: f76
title: Collapse the three day-stamp helpers into one
priority: 3
labels:
- chore-timeline-api
deps: []
closed: false
---
This package writes a zero-padded `[year][month][day]` sort key in three places,
with three names, and one of the comments about it is already false:

- `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/fragment.typ:76` — `_day-of`.
- `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ:13` — `_stamp`,
  byte-identical to `_day-of`, which `when.typ` already has in scope: it stars
  `read.typ`, which stars `fragment.typ`.
- `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ:98` — `_key`, the
  same `display` call with a `"zzzzzzzz"` default for an absent date. Its comment
  says it does not use "`_stamp` from `when.typ`, which is private and carries a
  time component this does not want" — but `_stamp` is day-only. The helper that
  carries a time component is `_stamp-of` (`fragment.typ:78`), and it is the one
  helper here that is genuinely distinct.

Three implementations, and the drift has already reached the prose. Internal only:
no exported name or behaviour changes.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/fragment.typ

## Steps

1. Delete `_stamp` from `when.typ:13` and its comment block, and replace its nine
   call sites in that file — lines 54, 70, 71, 85, 105, 106, 112, 113, 123, 124 —
   with `_day-of`. Nothing else needs to change: the comparison semantics are
   identical, day granularity in both.
2. In `upcoming.typ`, rewrite `_key` as
   `if d == none { "zzzzzzzz" } else { _day-of(d) }` and replace its comment with
   one line: what `"zzzzzzzz"` buys (every undated row sorts after every dated one
   with no second comparison). Drop the false claim about `_stamp`.
3. In `fragment.typ`, move the reasoning that justified the format — fixed width,
   so string order is date order, the same device `@rookery/core`'s `_sort-ids`
   uses — onto `_day-of` at line 76, where it now belongs for the whole package,
   and trim the duplicate of it from the `_stamp-of` block above so the two
   helpers are distinguished by what they DO: `_day-of` is the day, `_stamp-of`
   adds the clock where an entry has one.
4. Leave `_iso` (`upcoming.typ:103`) alone. It is a different format for a
   different consumer — the `datetime` attribute a machine reads — and its comment
   already says so.

## Non-goals

- **No API change.** All four helpers are private and stay private.
- **Do not unify `_stamp-of` into this.** It carries the time of day where an
  entry has one, and `fragment.typ:58-75` explains why the log's sort needs that;
  `#timeline-view` depends on the two being different (`view.typ:69-75`).
- **Do not change `_iso`.**
- **Do not reformat or re-order anything else in the three files.**

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test` — `units OK` then
   `views OK`. The view check asserts date ordering, the undated row sorting last,
   and same-day events showing their times, which is the whole surface these
   helpers feed.
2. `rg -n '_stamp\b' /home/lox/code/_fcl/rookery/timeline` returns nothing —
   only `_stamp-of` survives.
3. `rg -n 'display\("\[year\]\[month\]\[day\]"\)'
   /home/lox/code/_fcl/rookery/timeline/0.1.0/src` returns exactly one line,
   `fragment.typ`'s `_day-of`.
4. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check` and
   `cd /home/lox/code/_fcl/rookery/cfps/0.1.0 && just test` both pass.