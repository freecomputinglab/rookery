---
id: rk-hoist-in-progress-todos-to-the-top-d3a08506
short-id: d3
title: Hoist in-progress todos to the top
priority: 3
labels:
- feat-todos-in-progress
deps: []
closed: false
---
A todo whose `status:` is `"in-progress"` sorts by its date like every other
row, so the thing actually being worked on lands wherever its deadline puts it —
often below rows nobody has started. It should sit at the top of the list, in
both `#todo-table` and `#today-panel`.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ

## Where the order is decided — one place, not two

`#today-panel` (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ:45`) does
no ordering of its own. It selects rows with `_on-today` and hands them to
`#todo-table` (the call at `today.typ:132`), forwarding `order:` and
`undated-priority:` unchanged. **So a single change inside `#todo-table` fixes
both views**, and there is nothing to edit in `today.typ`.

Inside `#todo-table`
(`/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ:135`) the final order is
`@rookery/search`'s `#panel`, called at `table.typ:552` with
`sort: "when"` (`table.typ:576`) and `descending: order == "newest"`
(`table.typ:577`). `#panel` (`/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ:479-487`)
reads that field off each row, compares it as a plain ASCENDING string, maps a
`none` to the sentinel `"\u{ffff}"` so unset rows sort last, and then reverses
the whole list when `descending` is true.

The priority pre-sort at `table.typ:341-345` is NOT the list's order. It is only
a tie-break: Typst's `sorted` is stable, so rows sharing a `when` keep the order
they arrived in. A dated in-progress row is therefore untouched by it.

**This is why the hoist has to be a leading character on the sort key.** The
list's order belongs to `#panel`, `#panel` orders by one string field, and a
character that sorts before every date stamp puts a row above every date.

## Decisions already made — do not re-derive

- **Project a NEW field, `sort-key`, and point `sort:` at it.** Do not overload
  `when`: that field is the date stamp itself, `when-date` beside it is what
  `render:` formats, and an in-progress row with a doctored `when` would draw
  the wrong date.
- **`sort-key` costs no HTML attribute.** `#panel` emits one `data-<field>` per
  entry in `facets:` and only those (`panel.typ:568-576`), so a projected field
  that is not a facet rides build-time only — exactly as `when` and `when-date`
  already do. **Do not add `"sort-key"` to `facets:`**, `multi:`, `union:` or
  `pill-rows:`.
- **The leading character must flip under `order: "newest"`.** `#panel` reverses
  the entire list when `descending` is true, so a fixed `"0"` prefix would sink
  the in-progress rows to the bottom precisely when the caller asked for the
  most pressing thing first. `table.typ:341-345` already applies this same
  inversion to the priority tie-break and says so in its comment; match it.
- **Restate `#panel`'s undated sentinel inside the key.** Once every row has a
  `sort-key`, none of them is `none`, so `panel.typ:483`'s "unset sorts last"
  never fires. Append `"\u{ffff}"` for an undated row yourself, which keeps the
  current behaviour exactly: undated last while ascending, first under
  `"newest"`.
- **Hoist on the DERIVED state, not on `row.status`.** `_state-of`
  (`table.typ:127-133`) returns `"in-progress"` only for a row that is neither
  closed nor blocked; a blocked todo reads `"blocked"` however its `status:` is
  written. Using the derived value keeps the order agreeing with the badge the
  reader sees on the row.
- **Typst compares strings**, so `"0" + stamp` against `"1" + stamp` is an
  ordinary comparison and needs no numeric conversion.
- **No JavaScript change.** `panel.js` and `todo-search.js` tie-break on each
  row's markup index (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/todo-search.js:184`
  and its comment at 182-183), so the build-time order this bird changes is the
  order the browser keeps. Do not touch any `.js` file.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Steps

1. In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ`, add a pure helper
   at module level immediately after `_state-of`, which ends at line 133 with
   the line `}` following `  "scheduled"`:

   ```typ
   // THE STRING `#panel` ORDERS THE LIST BY. It compares `sort:` ascending and
   // reverses the whole list under `descending:`, so a row is hoisted above every
   // date by a LEADING CHARACTER rather than by a second pass — and that character
   // flips under `"newest"`, because the reversal would otherwise sink exactly the
   // rows the hoist lifted. The priority tie-break below inverts for the same reason.
   //
   // THE UNDATED SENTINEL IS RESTATED HERE. `#panel` maps a `none` sort value to
   // `\u{ffff}` so an unset row sorts last; every row carries a key now, so that
   // branch no longer fires and the sentinel has to ride inside the key.
   #let _sort-key(state, when, order) = {
     let newest = order == "newest"
     let lead = if state == "in-progress" {
       if newest { "1" } else { "0" }
     } else if newest { "0" } else { "1" }
     lead + (if when == none { "\u{ffff}" } else { when })
   }
   ```

2. In the same file, in the `.map` that projects each row (it opens at
   `table.typ:351` with `let rows = ranked` / `.map(r => {` and currently reads
   `let d = when(r)` then a dictionary literal), lift `state` and the date stamp
   into locals so the key can be built from them, and add the `sort-key` field.
   Replace lines 351-368 — from `let rows = ranked` down to and including the
   line `    })` that closes the `.map` — with:

   ```typ
     let rows = ranked
       .map(r => {
         let d = when(r)
         let state = _state-of(r, graph, today)
         // A ZERO-PADDED `[year][month][day]` STRING, because `#panel` sorts its sort
         // field as a plain string — which is date order exactly when it is padded.
         let stamp = if d == none { none } else { d.display("[year][month][day]") }
         (
           ..r,
           state: state,
           epic: epic-of(r.tags-dict),
           // AN ARRAY, the one non-scalar field here, and legal because `tag` is named in
           // `multi:` below. Sorting is @rookery/search's job: it dedups and sorts the
           // union across every listed row, so the pill order is stable across builds.
           tag: _tags-of(r.tags-dict, keep: tag-filter),
           // A pill reading "p7" says what the number is, and a pill reading "0" would
           // read as a count of something — so priority 0, the unprioritised default,
           // projects to no pill at all.
           priority: if r.priority == 0 { none } else { "p" + str(r.priority) },
           when: stamp,
           when-date: d,
           // NOT A FACET, so it becomes no attribute — `#panel` emits one `data-<field>`
           // per entry in `facets:` and this is not one of them.
           sort-key: _sort-key(state, stamp, order),
         )
       })
   ```

   Leave the `.filter(r => overdue or not _past(...))` line that follows the
   `.map` exactly as it is.

3. In the same file, at `table.typ:576`, change the `#panel` argument
   `sort: "when",` to `sort: "sort-key",`. Leave `descending: order == "newest",`
   on the next line unchanged.

4. Append to `/home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ`, at the end
   of the file (the last block there is the `_top-priority` / `_on-today` one):

   ```typ

   // ---- _sort-key — what puts an in-progress todo at the top ---------------
   //
   // `#todo-table` hands `#panel` one string per row and `#panel` compares it
   // ascending, so the hoist is a leading character rather than a second pass.

   // Ascending (`order: "soonest"`, the default): the leading character alone
   // separates an in-progress row from every other one.
   #assert.eq(_sort-key("in-progress", "20260825", "soonest"), "020260825")
   #assert.eq(_sort-key("ready", "20260825", "soonest"), "120260825")
   // So an in-progress row outranks a READY row with an earlier date.
   #assert(
     _sort-key("in-progress", "20260825", "soonest")
       < _sort-key("ready", "20260101", "soonest"),
   )
   // An undated row keeps `#panel`'s own "unset sorts last" sentinel, within
   // its own group — and an undated in-progress row still beats a dated one.
   #assert.eq(_sort-key("ready", none, "soonest"), "1\u{ffff}")
   #assert(
     _sort-key("in-progress", none, "soonest")
       < _sort-key("ready", "20260101", "soonest"),
   )
   // Under `"newest"` `#panel` reverses the whole list, so the character flips
   // and the hoist survives the reversal.
   #assert(
     _sort-key("in-progress", "20260825", "newest")
       > _sort-key("ready", "20260825", "newest"),
   )
   ```

   `units.typ` imports `/src/lib.typ` with `*`, and `lib.typ:29` re-exports
   `table.typ` with `*`, so a module-level `#let _sort-key` there is in scope
   with no import to add.

## Do NOT

- Do not edit `/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ`. It
  forwards to `#todo-table` and has no order of its own.
- Do not edit anything under `/home/lox/code/_fcl/rookery/search/`. `#panel`'s
  sort is correct; this bird changes only what it is pointed at.
- Do not touch any `.js` file, or `src/todos.css`.
- Do not change the priority pre-sort at `table.typ:341-345`, `undated-priority:`,
  the `order:` / `descending:` pairing, or the `overdue` filter after the `.map`.
- Do not add `"sort-key"` to `facets:`, `multi:`, `union:` or `pill-rows:`.
- Do not change the colour or styling of an in-progress row — a separate bird
  covers that, and it edits `src/todos.css` only.

## VERIFY

Both of these are green today and must stay green:

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

No separate `just build` is needed for this bird. `typst.toml`'s `entrypoint`
points at `src/lib.typ`, so a Typst edit takes effect immediately — `dist/` holds
only the JavaScript bundle (`dist/lib.js`), which this bird does not touch.
`just check` runs `build` as a prerequisite anyway. (The `build` recipe's own
comment in the `Justfile` claims `typst.toml` points at `dist/`; it is stale —
believe `typst.toml`.)

Expected: `just test` compiles `test/units.typ` without a panic and prints
`units OK` — the six new `assert`s are the decisive part, and a wrong leading
character fails the compile with a line number. `just check` builds the demo and
runs `demo/rheo/check.sh`, which asserts on the generated markup.

If `just check` reports a changed row order in the demo, read the assertion
before changing anything: a demo fixture with an in-progress todo SHOULD move,
and that is this bird landing rather than a regression. Fix the fixture's
expectation, not the sort.