---
id: rk-scale-the-priority-ramp-from-listed-rows-c0476e1e
short-id: c04
title: Scale the priority ramp from listed rows
priority: 4
labels:
- feat-todo-band-order
deps: []
closed: false
---
`#todo-table` places a row's priority on the heat ramp against
`priority-scale()`, which walks **every** todo in the rookery — closed ones
included. One closed high-priority todo therefore sets a rung no open row can
reach, and every open row slides one rung cooler than it should be.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/readme.md

## What is wrong

`/home/lox/code/_fcl/rookery/todos/0.1.0/src/graph.typ` line 54 is:

```typ
#let priority-scale() = todos().map(r => r.priority).filter(p => p > 0).dedup().sorted().rev()
```

`todos()` is the whole registry. `/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ`
line 336 calls it once per panel:

```typ
  let scale = priority-scale()
```

and line 452 uses that scale to place each row on the three-step ramp:

```typ
      let rung = priority-rung(if p == none { none } else { int(p.slice(1)) }, scale)
```

`/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ` lines 17-28 already
refuse `priority-scale()` for exactly this reason, and its comment states the
failure in full: a closed todo at priority 9 sets a band no open row could
ever reach. `#todo-table` has the same problem and has not had the same fix.

`/home/lox/code/_fcl/rookery/cfps/0.1.0/src/panel.typ` line 155 is the shape
to copy — a sibling package in this repo computing its scale from the rows it
is about to draw:

```typ
    let scale = rows.map(r => r.priority).filter(p => p > 0).dedup().sorted().rev()
```

## What to do

1. In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ`, delete the
   `let scale = priority-scale()` line at 336 and its two-line comment above
   it (lines 334-335, which begin "ONCE, not per row").

2. Compute the scale from the rows the panel actually lists, immediately
   **after** the `let ranked = ...` block that currently ends at line 364 —
   it has to come after `keep` has run, which is the whole point:

   ```typ
   // THE SCALE IS THE PRIORITIES THIS PANEL LISTS, not every priority in the
   // rookery: `priority-scale()` walks closed todos too, and one closed todo at
   // a priority no open row carries sets a rung nothing on the page can reach,
   // sliding every listed row one step cooler than it is.
   //
   // ONCE, not per row: `priority-rung` places a priority relative to this
   // scale, and the scale does not change while rendering one panel.
   let scale = ranked.map(r => r.priority).filter(p => p > 0).dedup().sorted().rev()
   ```

3. Leave `priority-scale()` in `graph.typ` exactly as it is. It is a public
   export of this package and its documented meaning — every priority in the
   rookery — is still the right answer to the question it asks. After this
   change nothing in this repo calls it, and that is fine.

4. Do not touch `priority-rung` (`tags.typ` line 293) or its `rungs: 3`
   default. This bird changes which scale a row is measured against, not how
   many steps the ramp has.

5. In `/home/lox/code/_fcl/rookery/todos/0.1.0/readme.md`, find the prose in
   the `## Grouped pills: #todo-table` section (header at line 381) that
   describes the priority ramp — the paragraph around line 509 that explains
   `undated-priority:` — and add one sentence stating that a row's rung is
   relative to the priorities **this panel lists**, not to every priority in
   the rookery. Do not restructure the section.

## Non-goals

- Do not change `priority-scale()`'s definition. Changing it would be a
  silent behaviour change for every consumer of a public export, to fix one
  caller.
- Do not touch `/home/lox/code/_fcl/rookery/cfps/0.1.0/src/panel.typ`. It
  already computes its own scale correctly; it is cited here only as the
  pattern.
- Do not touch `/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ`.
- No new public parameter. The scale is derived, not configured.

## Comment style

This repo's `CLAUDE.md` (lines 66-98) forbids comments that describe history:
no "used to", no "moved from", no bird ids, no branch names. Write the comment
above as a statement about what the code is and why. Emphasis capitals are for
the one claim in a block that carries it.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/todos/0.1.0`:

1. `just test` — compiles `test/units.typ` and runs `test/panics.sh`. Must
   pass. The `priority-rung` assertions at `test/units.typ` lines 82-90 test
   the pure helper and must still pass untouched; if you had to edit them, you
   changed `priority-rung` and should not have.

2. `just check` — `rheo compile demo/rheo && ./demo/rheo/check.sh`. Must pass.

3. Add one assertion to `/home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ`
   proving the scale is relative rather than absolute, in the
   `priority-rung` block near line 82:

   ```typ
   // A scale drawn from three listed priorities puts the hottest of THEM on
   // rung 0, whatever larger priority exists elsewhere in the rookery.
   #assert.eq(priority-rung(4, (4, 3, 2)), 0)
   #assert.eq(priority-rung(4, (9, 4, 3, 2)), 1)
   ```

4. `bd status <this bird's id>` reports this bird as in flight while you work
   it. Do not try to close the bird yourself — landing the flight retires it.