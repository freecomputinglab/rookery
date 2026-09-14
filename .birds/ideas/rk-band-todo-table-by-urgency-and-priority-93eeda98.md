---
id: rk-band-todo-table-by-urgency-and-priority-93eeda98
short-id: 93e
title: Band todo-table by urgency and priority
priority: 4
labels:
- feat-todo-band-order
deps:
- blocked-by:rk-scale-the-priority-ramp-from-listed-rows-c0476e1e
closed: true
---
`#todo-table` orders rows by date alone, so the most important todo on a site
sinks below every dated one. Interleave the two ladders the package already
has: a row's **band** becomes the sooner of its countdown band and its
priority rung, so the top priority floats to the top alongside what is due
today.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/readme.md, /home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/content/index.typ

## The order wanted

Four bands, read top to bottom. A row sits in the **lowest-numbered** band it
qualifies for by either ladder:

| band | countdown level | priority rung |
|------|-----------------|---------------|
| 0    | `urgent` — overdue, today, tomorrow | hottest priority in use |
| 1    | `soon` — 2 to 7 days | second hottest |
| 2    | `later` — 8 to 14 days | third hottest |
| 3    | no level — more than 14 days out, or undated | fourth hottest and below, or unprioritised |

So the hottest priority appears in band 0 whatever its date, and a todo due
tomorrow appears in band 0 whatever its priority. A todo with both stays in
band 0. A P-hottest todo dated eight months out is band 0.

Within one band, in this order:

1. In-progress rows first.
2. Then rows that carry a date, earliest first.
3. Then rows with no date, highest priority first.

Rule 2 before rule 3 is the point: a scheduled or deadlined todo outranks one
that is in the band on priority alone.

## What exists already

Both ladders are in the repo. Do not write a third.

**The countdown bands** are `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ`
line 190, `#countdown(days)`, returning `(text: .., level: ..)` or `none`:

```typ
#let countdown(days) = {
  if days == none { return none }
  if days > 14 { return none }
  if days < -1 { return (text: str(-days) + " days ago", level: "urgent") }
  if days == -1 { return (text: "yesterday", level: "urgent") }
  if days == 0 { return (text: "today", level: "urgent") }
  if days == 1 { return (text: "tomorrow", level: "urgent") }
  if days <= 7 { return (text: "in " + str(days) + " days", level: "soon") }
  (text: "in " + str(days) + " days", level: "later")
}
```

`/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ` already imports it as
`_tl` (line 36) and already calls it at lines 405-406 to pick the date cell's
colour wash:

```typ
      let c = if countdown and d != none and today != none {
        _tl.countdown(_tl.days-until(d, today))
      } else { none }
```

**You must map from `countdown(..).level`, not re-derive the cutoffs.** The
comment at `table.typ` lines 402-405 states the rule: a second copy of
`if days <= 7` in this file is how two surfaces drift apart. The cutoffs live
in `when.typ` and only there.

**The priority ladder** is `/home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ`
line 293, `#priority-rung(p, scale, rungs: 3)`: the index of `p` in `scale`
(the distinct priorities in use, hottest first), clamped to `rungs - 1`, and
`none` for priority 0 or a priority absent from the scale.

**The scale** is a `let scale = ...` in `table.typ`, computed from the rows the
panel lists. Read the line where it is set before writing any code — a
preceding bird moved it, so its line number is not the one this description
would have given.

## The current key, and why it is a string

`/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ` line 144:

```typ
#let _sort-key(state, when, order) = {
  let newest = order == "newest"
  let lead = if state == "in-progress" {
    if newest { "1" } else { "0" }
  } else if newest { "0" } else { "1" }
  lead + (if when == none { "\u{ffff}" } else { when })
}
```

It is one string per row because that is `#panel`'s whole sort contract.
`/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ` lines 477-486
compares the named field as a plain string, ascending, and reverses the whole
list under `descending:`:

```typ
    let s = rows.sorted(key: key)
    if descending { s.rev() } else { s }
```

`table.typ` line 598 passes `sort: "sort-key"` and line 599 passes
`descending: order == "newest"`. Two consequences you must honour:

- **Every leading field must be complemented under `"newest"`**, or the
  reversal sinks exactly the rows it lifted. That is what the existing `lead`
  flip does, and the new fields need the same treatment.
- **Typst's `sorted` is stable**, which is what makes the priority pre-sort at
  `table.typ` lines 360-364 work as a tie-break rather than a competing order.
  Leave that block alone; it is what orders the undated rows within a band.

`#panel`'s browser script does not re-sort: `search/0.1.0/src/panel.js` line
299 sorts on score with the markup index as tie-break, and with an empty query
every score is equal, so the Typst-side order survives filtering. No
JavaScript changes in this bird.

## What to do

1. In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ`, add a private
   mapping from a countdown level to a band number, near `_past` (line 55):

   ```typ
   // A COUNTDOWN LEVEL AS A BAND NUMBER. The cutoffs that produce the level are
   // @rookery/timeline's and stay there; this is only the ordering of the three
   // it returns, plus the fourth band every unmeasured row falls to.
   #let _LEVEL-BAND = ("urgent": 0, "soon": 1, "later": 2)
   #let _BANDS = 4
   ```

2. Add a private `_band`, beside it:

   ```typ
   // WHICH BAND A ROW READS IN: the sooner of the two ladders, so the hottest
   // priority rises to the top whatever its date and a deadline landing tomorrow
   // rises there whatever its priority. An in-progress row is band 0 outright —
   // someone is on it now, which is the one fact neither ladder can express.
   //
   // `rungs: _BANDS` rather than `priority-rung`'s own default of three: the
   // priority ladder has to be as long as the date ladder for the two to
   // interleave, and the coolest band is where an unprioritised row lands.
   #let _band(row, days, scale) = {
     if row.status == "in-progress" { return 0 }
     let c = _tl.countdown(days)
     let date-band = if c == none { _BANDS - 1 } else { _LEVEL-BAND.at(c.level) }
     let rung = priority-rung(row.priority, scale, rungs: _BANDS)
     let pri-band = if rung == none { _BANDS - 1 } else { rung }
     calc.min(date-band, pri-band)
   }
   ```

3. Replace `_sort-key` (line 144) and its comment block (lines 135-143) with a
   version that takes the band. Keep the `\u{ffff}` sentinel and keep the
   complementing:

   ```typ
   // THE STRING `#panel` ORDERS THE LIST BY. It compares `sort:` ascending and
   // reverses the whole list under `descending:`, so every field ahead of the
   // date is complemented under `"newest"` — otherwise the reversal sinks
   // exactly the rows the ordering lifted. The date itself is not complemented:
   // reversing it is what `"newest"` means.
   //
   // FOUR FIELDS, widest first: the band, then in-progress, then whether the row
   // carries a date at all — a scheduled or deadlined todo reads above one that
   // is in the band on priority alone — then the date. An undated row keeps
   // `#panel`'s own `\u{ffff}` sentinel, and the priority pre-sort is what orders
   // those rows among themselves.
   #let _sort-key(band, state, when, order) = {
     let newest = order == "newest"
     let flip(i, n) = if newest { str(n - 1 - i) } else { str(i) }
     flip(band, _BANDS)
       + flip(if state == "in-progress" { 0 } else { 1 }, 2)
       + flip(if when == none { 1 } else { 0 }, 2)
       + (if when == none { "\u{ffff}" } else { when })
   }
   ```

4. Add `"urgency"` as a third legal `order:` and make it `#todo-table`'s
   default. At line 236 the parameter currently reads `order: "soonest",` —
   change it to `order: "urgency",` and rewrite its doc comment (lines 233-235)
   to state the three values and what each one means. Widen the assertion at
   lines 318-323 to accept `"urgency"` and name it in the message.

5. Keep `"soonest"` and `"newest"` behaving exactly as they do now — the old
   key, no bands. In the row map at line 389, pick the key by order:

   ```typ
         let band = _band(r, if d == none or today == none { none } else {
           _tl.days-until(d, today)
         }, scale)
   ```

   and then, where `sort-key:` is set:

   ```typ
         sort-key: if order == "urgency" {
           _sort-key(band, state, stamp, order)
         } else {
           _sort-key(_BANDS - 1, state, stamp, order)
         },
   ```

   Passing the coolest band for every row under the two old orders makes that
   field constant, which leaves the key ordering by exactly what it ordered by
   before — in-progress, then dated, then date — with one extra constant
   character in front. That is why `"soonest"` needs no second key function.

6. Project `band` as a plain row field in the same map, beside `when-date`:

   ```typ
         band: band,
   ```

   **Not a facet.** `#panel` emits one `data-<field>` attribute per entry in
   `facets:` and this is not one of them; the comment at `table.typ` line 387
   already states that rule for `sort-key`. A following bird filters on this
   field, and a caller's `render:` can read it.

7. `descending: order == "newest"` at line 599 stays exactly as it is.
   `"urgency"` is ascending.

8. Do not change the `let ranked = ...` block at lines 360-364. It sorts by
   descending priority before `#panel`'s stable sort, which is what puts the
   undated rows of a band in priority order, and it already reverses itself
   under `"newest"`.

## When there is no reference date

`_band` needs `days`, and `days` needs `today:`. With `today: none` nothing is
measurable, so every row's `date-band` is the coolest one and the ordering
falls back to priority bands with dated rows first inside each. This is
correct and needs no special case — but say so in one sentence in the
`order:` doc comment, because a caller who forgets `today:` gets an order that
looks arbitrary rather than an error. Nothing in this package may call
`datetime.today()`; the comment at `table.typ` lines 166-169 says why.

## Non-goals

- **No `bands:` parameter.** Filtering rows by band is a separate bird.
- **No `hoist:` parameter.** A site declaring its own band-0 rows is a
  separate bird.
- **No band pill group and no band CSS class.** `band` is a field and nothing
  more in this bird. Do not add it to `facets:`, `pill-rows:`, `row-class:` or
  `todos.css`.
- **Do not touch `#today-panel`** (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ`).
  It passes `order: "soonest"` explicitly at line 109 and must keep doing so;
  a later bird removes the file outright.
- **Do not touch `priority-rung`** (`tags.typ` line 293) or its `rungs: 3`
  default. The date cell's colour wash at `table.typ` line 452 keeps calling it
  with the default, because the CSS heat ramp has three steps. The ordering
  asks for four. Those are two different questions about the same scale.
- No JavaScript changes.

## A name that is already taken, and is not a conflict

`table.typ` line 437 has a local `let band = ...` inside the row renderer,
holding a CSS class name. A row field called `band` does not collide with it —
the local shadows nothing, and `r.band` still reads the field. Leave the local
alone.

## Comment style

This repo's `CLAUDE.md` lines 66-98: describe the present, never the history.
No "used to sort by date", no "this replaces", no bird id, no branch name. One
header per file and no interior `// ---- Section ----` dividers. Emphasis
capitals for the one claim in a block that carries it.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/todos/0.1.0`:

1. Rewrite the `_sort-key` assertions in
   `/home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ` lines 546-572.
   They assert the old two-part key and will not compile — the header comment
   at 546 and the seven assertions below it all go. `test/units.typ` reaches
   privates through `#import "/src/lib.typ": *` at line 5, so `_band`,
   `_sort-key`, `_LEVEL-BAND` and `_BANDS` are all in scope with no new import.
   Assert at least:

   ```typ
   // The hottest priority in use is band 0 whatever its date.
   #assert.eq(_band((status: "open", priority: 4), 200, (4, 3, 2)), 0)
   // A deadline tomorrow is band 0 whatever its priority.
   #assert.eq(_band((status: "open", priority: 2), 1, (4, 3, 2)), 0)
   // The ladders interleave: third-hottest priority, three weeks out.
   #assert.eq(_band((status: "open", priority: 2), 21, (4, 3, 2)), 2)
   // Neither ladder says anything: the coolest band.
   #assert.eq(_band((status: "open", priority: 0), none, (4, 3, 2)), 3)
   // In progress outranks both ladders.
   #assert.eq(_band((status: "in-progress", priority: 0), none, (4, 3, 2)), 0)
   // Inside one band a dated row reads above an undated one, and band 0 reads
   // above band 1 whatever the dates say.
   #assert(_sort-key(0, "open", none, "urgency") < _sort-key(1, "open", "20260101", "urgency"))
   #assert(_sort-key(0, "open", "20261231", "urgency") < _sort-key(0, "open", none, "urgency"))
   // Complementing survives the reversal `descending:` applies under "newest".
   #assert(_sort-key(0, "open", "20260825", "newest") > _sort-key(1, "open", "20260825", "newest"))
   ```

2. `just test` — `typst compile --features html --root . --format pdf test/units.typ /dev/null && ./test/panics.sh`. Must pass.

3. `just check` — `rheo compile demo/rheo && ./demo/rheo/check.sh`. Must pass.
   If `check.sh` asserts a row order that this change alters, fix the assertion
   to the new expected order rather than reverting the change — but read the
   assertion first and say in your landing message which one moved and why.

4. `/home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/content/index.typ` line
   124 narrates "An OVERDUE todo — a deadline already behind `TODAY`.
   `#todo-table` lists it first". Still true under the new order (overdue is
   `urgent`, so band 0, and dated rows sort earliest-first inside a band), so
   leave it — unless the demo happens to also carry a hotter-priority undated
   todo, in which case correct the sentence.

5. In `/home/lox/code/_fcl/rookery/todos/0.1.0/readme.md`, rewrite the
   ordering prose in the `## Grouped pills: #todo-table` section (header line
   381; the relevant paragraphs run roughly 491-532) to describe the four
   bands, the two ladders, the within-band order, and the three `order:`
   values. Include the band table from this bird. Do not touch the
   `## A day view: #today-panel` section at line 533, and do not confuse
   `#todo-table`'s `order:` with `#todo-slipshow`'s unrelated `order:`
   documented at readme lines 626-711.

6. `just test-js` — `node --test test/*.test.mjs`. Must pass unchanged; no
   JavaScript is in scope.