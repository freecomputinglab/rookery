---
id: rk-hoist-upcoming-rows-filter-key-3fa421e8
short-id: 3fa
title: Hoist upcoming-rows filter key computation
priority: 4
labels:
- chore-timeline-review
deps: []
closed: false
---
**Hoist loop-invariant date-key computation out of `upcoming-rows`'s row filter.**

`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ`, function
`upcoming-rows` (starts at line 209), the filter step at lines 285-290:

```typ
  let rows = rows.filter(r => {
    if r.when == none { return true }
    if from != none and r.key < _key(from) { return false }
    if within != none and r.key > _key(_today(today) + duration(days: within)) { return false }
    true
  })
```

`from` and `within` are `upcoming-rows`'s own arguments — fixed for the whole
call, not something that varies per row `r`. But `_key(from)` on line 287 and
`_key(_today(today) + duration(days: within))` on line 288 sit inside the
`.filter(r => ..)` closure, so Typst recomputes both on every row: for `N`
notes passed through `tags:`/`match:`/`filter:`, that is `N` calls to
`_key()`'s `.display(..)` (line 98's `#let _key(d) = if d == none {
"zzzzzzzz" } else { d.display("[year][month][day]") }`) for a value that is
identical on every iteration, plus, for the `within` bound, `N` redundant
calls to `_today(today)` (line 174 area — resolves/validates the reference
date) and `N` redundant `duration(days: within)` constructions and
`datetime + duration` additions — all producing the exact same result each
time.

This is the same shape as a defect already found and fixed in `@rookery/core`
(`_sort-ids`) and `@rookery/search` (`_rank`, `#filter-panel`): a value that
does not depend on the loop variable is recomputed once per loop iteration
instead of once before the loop. `@rookery/timeline` is exactly the kind of
package this pattern was flagged for — it sorts and filters dated things for
a living, and `upcoming-rows` is its main per-corpus hot path (it walks every
note the caller's `tags:`/`match:`/`filter:` selects, via `ideas()` at line
240).

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ

## Decisions already made — do not re-derive

- The fix is to compute the two bounds ONCE, before `.filter(..)` runs, as
  plain local bindings, then reference those bindings inside the closure
  instead of recomputing them.
- `from-key` should be `none` when `from == none` (matching the existing
  `from != none and ..` guard), and likewise `within-key` should be `none`
  when `within == none`.
- Do NOT change the comparison semantics: `r.key < from-key` must still drop
  the row (via `return false`) exactly when the old `r.key < _key(from)` did,
  and the same for the `within` bound. This is a pure hoist, not a behaviour
  change — `just test` must still print the same output as before.
- Do NOT touch `_key`, `_today`, `when-of`, the earlier `rows.map(..)` block
  (lines 250-281), or the final `rows.sorted(..)` / `limit` handling (lines
  292-294). Only the filter step at lines 285-290 changes.

## Steps

1. Open `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ`.
2. Immediately before the `let rows = rows.filter(r => {` line (currently
   line 285), insert two bindings:

   ```typ
   let from-key = if from == none { none } else { _key(from) }
   let within-key = if within == none { none } else { _key(_today(today) + duration(days: within)) }
   ```

3. Replace the body of the filter closure so it reads:

   ```typ
   let rows = rows.filter(r => {
     if r.when == none { return true }
     if from-key != none and r.key < from-key { return false }
     if within-key != none and r.key > within-key { return false }
     true
   })
   ```

4. Leave everything else in the file unchanged, including the two comment
   lines directly above the filter (lines 283-284, "Both bounds compare on
   the same zero-padded key the sort uses..." — that comment is still
   accurate and needs no edit).

## Do NOT

- Do not change `#upcoming` (the function starting at line 302) — it calls
  `upcoming-rows` and does not duplicate this filter logic.
- Do not add a cache/memoization mechanism, a new helper function, or a new
  parameter. Two local `let` bindings are the whole fix.
- Do not touch any other file in this package.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test
```

Must print exactly what it prints on the unmodified package: `units OK`, then
the two `typst compile --features html` HTML exports with only the existing
"html export is under active development" warnings (no new warnings or
errors), then `check.sh`'s two summary lines ending `views OK`, including the
unchanged line `upcoming: 4 rows in date order, undated last, 1 soft, badges
from the log, cutoff kept ['Booked', 'Later', 'Watched'], countdown chips
last in the strip across 5 bands with 2 silent` — that line exercises
`from:`/`within:` filtering (`test/upcoming.typ`), so if the hoist changed
behaviour this line's content would change or the compile would fail an
`assert.eq` in `test/units.typ`/`test/upcoming.typ`.