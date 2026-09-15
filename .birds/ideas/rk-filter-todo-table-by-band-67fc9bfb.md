---
id: rk-filter-todo-table-by-band-67fc9bfb
short-id: '67'
title: Filter todo-table by band
priority: 3
labels:
- feat-todo-band-order
deps:
- blocked-by:rk-add-a-hoist-predicate-to-todo-table-7ccfc18f
closed: true
---
`#todo-table` computes a band per row and orders by it, but always lists every
band. Add a `bands:` parameter so a page can show one band alone — which is
what a day view is: band 0.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/readme.md

## What exists

`/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ` projects a `band`
field onto every row — an integer 0 to 3, 0 being the top band — and orders by
it under `order: "urgency"`. Band 0 is a row that is overdue, due today or
tomorrow, at the hottest priority in use, in progress, or named by `hoist:`.
Read the row-projection map and the `_band` private before editing: preceding
birds added both, so their line numbers are not ones this description can give.

The row pipeline in `#todo-table` runs, in this order:

1. `let ranked = ...` — `filter:` applied, then a descending-priority pre-sort.
2. `let scale = ...` — the distinct priorities among `ranked`, hottest first.
3. `let rows = ranked.map(..).filter(r => overdue or not _past(..))` — the
   projection, which computes each row's `band` against `scale`, then the
   overdue drop.

## The one thing that must not be got wrong

**The band filter goes at the END of step 3, after the projection.** It must
not narrow `ranked`, and it must not run before `scale` is computed.

`scale` is the priorities of the rows the panel lists, and a row's priority
band is its rung on that scale. Filter first and the scale is drawn from an
already-narrowed set, so the hottest priority *remaining* becomes rung 0 —
which means every row in a `bands: (0,)` panel qualifies for band 0 by
definition and the filter selects everything. The band a row reads in has to
be decided against the whole panel's corpus, then filtered on.

## What to do

1. Add the parameter to `#todo-table`, immediately after `overdue:` (find it
   by name; preceding birds have edited this parameter list). Document it:

   ```typ
   // WHICH BANDS ARE LISTED. `auto` (the default) is all of them. An array of
   // band numbers keeps only those: `bands: (0,)` is a day view — what is
   // overdue, due today or tomorrow, at the hottest priority in use, in
   // progress, or named by `hoist:` — and nothing else.
   //
   // A ROW'S BAND IS DECIDED AGAINST THE WHOLE PANEL, then filtered on. The
   // priority half of the ladder is a rung on the scale of priorities this
   // panel lists, so narrowing the rows first would redraw the scale from the
   // survivors and make every one of them rung 0.
   //
   // IT NEEDS A `today:` to mean what it says. With no reference date no row is
   // measured, every row's date band is the coolest one, and `bands: (0,)`
   // keeps only the in-progress, hoisted and top-priority rows.
   bands: auto,
   ```

2. Append the filter to the end of the existing `.filter(r => overdue or not _past(..))`
   chain:

   ```typ
       .filter(r => bands == auto or r.band in bands)
   ```

3. Assert the argument's shape, beside the existing `order` assertion near the
   top of the function body:

   ```typ
   assert(
     bands == auto or type(bands) == array,
     message: "@rookery/todos: #todo-table's `bands` must be `auto` (every band) "
       + "or an array of band numbers, as in `bands: (0,)` — got " + repr(bands),
   )
   ```

4. Document it in `/home/lox/code/_fcl/rookery/todos/0.1.0/readme.md` in the
   `## Grouped pills: #todo-table` section (header at line 381), beside the
   band prose a preceding bird wrote. Show the day view as the motivating
   example:

   ```typ
   #todo-table(
     today: TODAY,
     bands: (0,),
     badge-pills: true,
     visible: none,
     placeholder: "Filter today",
     empty: [Nothing for today.],
   )
   ```

   State in one sentence that those four extra arguments are what make it read
   as a day view rather than a worklist: every badge pressable, no scroll box,
   and its own placeholder and empty text.

## Non-goals

- **Do not make `band` a facet or a pill.** It is not in `facets:`, so
  `#panel` emits no `data-band` attribute for it, and adding one is a separate
  feature. A reader narrowing by band is asking a different question from a
  reader pressing a pill.
- **Do not add a CSS class per band** and do not touch
  `/home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css`.
- **Do not remove or change `#today-panel`.** A later bird does that; this
  bird must land without touching
  `/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ`.
- Do not accept a single integer in place of an array. `bands: 0` and
  `bands: (0,)` differing by a comma is exactly the argument that gets
  mistyped; one shape, asserted.
- Do not reorder or renumber the bands.

## Comment style

This repo's `CLAUDE.md` lines 66-98: present tense, what the code is and why,
never what it replaced. No bird ids, no branch names.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/todos/0.1.0`:

1. `just test` — `typst compile --features html --root . --format pdf test/units.typ /dev/null && ./test/panics.sh`. Must pass.

2. `just check` — `rheo compile demo/rheo && ./demo/rheo/check.sh`. Must pass
   unchanged: the demo passes no `bands:`, so `auto` keeps every row and
   nothing there moves.

3. Prove the filter works against the demo corpus, which is the corpus
   `check.sh` already reasons about. Add to
   `/home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/content/index.typ`, in
   the `== Filter them in groups — #todo-table` section (header at line 231),
   a second call and one sentence of narration:

   ```typ
   #todo-table(today: TODAY, bands: (0,), noun: "todos", visible: none)
   ```

   Then `rheo compile demo/rheo` and confirm by reading
   `demo/rheo/build/html/index.html` that this list contains `mirror`
   (scheduled in the past), `invoice` (overdue), `renew` (due today), `ship`
   (this corpus's only priority-9 todo) and `migrate` (in progress), and does
   **not** contain `retro` (priority 2, scheduled in December). Those six rows
   are `check.sh`'s own expectations for the day view at
   `demo/rheo/check.sh` lines 202-234, so they are the right set to check
   against. If a demo todo is dated exactly tomorrow it belongs in the list
   too — band 0 includes tomorrow — so derive the set from the corpus at
   `demo/rheo/content/index.typ` rather than trusting this paragraph.

4. Do not add a `check.sh` assertion for the new section in this bird. A later
   bird rewrites that file's day-view block wholesale, and two birds editing it
   is a conflict for no gain.