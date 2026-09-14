---
id: rk-add-a-hoist-predicate-to-todo-table-7ccfc18f
short-id: 7c
title: Add a hoist predicate to todo-table
priority: 3
labels:
- feat-todo-band-order
deps:
- blocked-by:rk-band-todo-table-by-urgency-and-priority-93eeda98
closed: true
---
`#todo-table`'s band 0 is derived from dates and priority, and that is every
reason a todo can be urgent **except** the one only the site knows: a hand-set
tag meaning "on for today whatever the dates say". Give the panel a `hoist:`
predicate so a site can put such a row in band 0 outright.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/readme.md

## Why this parameter exists

`/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ` line 77 has the same
hole, named `also:`, and its comment (lines 70-76) states the case in full:

> A predicate over a row that ORs INTO the day's selection, where `filter:`
> narrows it instead. It is the one hole this package cannot fill for itself: a
> site may have a reason a todo belongs on today's list that no date or
> priority captures — a hand-set tag meaning "on for today whatever the dates
> say", say — and every other argument here can only ever REMOVE rows from the
> selection.

One real consumer depends on it. `/home/lox/code/waterline/rookery/_lib/template.typ`
line 36 defines `#let TODAY-TAG = "today"`, and line 34 calls it "A hand-set
tag, NOT derived from any date". `/home/lox/code/waterline/rookery/index.typ`
passes `also: r => TODAY-TAG in r.tags-dict`. That tag matches no date and no
priority, so without `hoist:` it can never reach band 0.

This is `also:` moved one layer down, from the day view into the panel the day
view is built on. Do not name it `also:` — that name meant "add this row to a
selection", and this one means "this row reads in band 0". Different claim.

## What `_band` looks like now

`/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ` holds a private
`_band(row, days, scale)` returning a band number 0 to 3, where 0 is the top
band. It returns 0 for an in-progress row, and otherwise the lower of the
row's countdown band and its priority rung. Read the function before editing
it — a preceding bird added it, so its line number is not one this description
can give.

## What to do

1. Give `_band` a `hoist:` keyword argument defaulting to `none`, tested in
   the same place the in-progress check already sits — both are reasons a row
   is band 0 regardless of either ladder:

   ```typ
   #let _band(row, days, scale, hoist: none) = {
     if hoist != none and hoist(row) { return 0 }
     if row.status == "in-progress" { return 0 }
     ...
   }
   ```

   Extend its comment with one sentence: a site's own reason for a row being
   in the top band, which no date and no priority can express.

2. Add the parameter to `#todo-table`, immediately after `filter:` (which is
   at line 228 before this bird — find it by name, not by number, since a
   preceding bird has edited this parameter list). Document it:

   ```typ
   // ROWS THIS SITE PUTS IN THE TOP BAND, as a predicate over a row —
   // `r => bool`, `none` for none of them. A site may have a reason a todo is
   // urgent that no date and no priority captures — a hand-set tag meaning "on
   // for today whatever the dates say" — and band 0 is otherwise derived
   // entirely from the two ladders.
   //
   // NOT `filter:`, which decides which rows are rows at all. This one cannot
   // add a row or remove one; it only moves a row that is already listed into
   // the top band.
   hoist: none,
   ```

3. Forward it at the `_band(..)` call in the row map:

   ```typ
         let band = _band(r, ..., scale, hoist: hoist)
   ```

4. Document it in `/home/lox/code/_fcl/rookery/todos/0.1.0/readme.md`, in the
   `## Grouped pills: #todo-table` section (header at line 381), beside the
   band prose a preceding bird wrote there. One short paragraph and one
   example:

   ```typ
   #todo-table(today: TODAY, hoist: r => "today" in r.tags-dict)
   ```

## Non-goals

- **Do not remove or change `#today-panel`'s `also:`.** A later bird removes
  that whole file; this bird leaves it alone so the two can land
  independently.
- **No `bands:` parameter.** That is a separate bird.
- Do not make `hoist:` able to demote a row to a cooler band. It promotes to
  band 0 or does nothing — a predicate returning a bool cannot say which band,
  and a site that wants to reorder the ladder itself wants a different feature.
- Do not give `hoist:` a default that reads any particular tag. `"today"` is
  one site's convention and this package declares no tag vocabulary of its own
  beyond the `todo` namespace.

## Comment style

This repo's `CLAUDE.md` lines 66-98: present tense, describe what the code is
and why, never what it replaced or where it moved from. No bird ids, no branch
names. Emphasis capitals for the one claim in a block that carries it.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/todos/0.1.0`:

1. Add assertions to `/home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ`
   beside the existing `_band` block. Privates are in scope through
   `#import "/src/lib.typ": *` at line 5, so no new import is needed:

   ```typ
   // A hoisted row is band 0 with no date and no priority at all.
   #assert.eq(
     _band((status: "open", priority: 0, tags-dict: ("today": none)), none, (4, 3, 2), hoist: r => "today" in r.tags-dict),
     0,
   )
   // The predicate only promotes: a row it says nothing about keeps its ladder band.
   #assert.eq(
     _band((status: "open", priority: 0, tags-dict: (:)), none, (4, 3, 2), hoist: r => "today" in r.tags-dict),
     3,
   )
   // `hoist: none` is the default and changes nothing.
   #assert.eq(_band((status: "open", priority: 0, tags-dict: (:)), none, (4, 3, 2)), 3)
   ```

2. `just test` — `typst compile --features html --root . --format pdf test/units.typ /dev/null && ./test/panics.sh`. Must pass.

3. `just check` — `rheo compile demo/rheo && ./demo/rheo/check.sh`. Must pass
   unchanged: the demo passes no `hoist:`, so nothing there moves.