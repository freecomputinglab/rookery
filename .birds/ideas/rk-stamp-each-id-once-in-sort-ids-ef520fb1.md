---
id: rk-stamp-each-id-once-in-sort-ids-ef520fb1
short-id: ef
title: Stamp each id once in _sort-ids
priority: 2
labels:
- chore-core-review
deps:
- blocked-by:rk-cache-bib-keys-drop-dead-cite-walk-871b6099
closed: false
---
`_sort-ids` formats every note's `created` datetime between four and N+3 times
when a `#window` sorts by date. Compute each stamp once and group on it.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/pure.typ

## What is wrong

`_sort-ids(ids, reg, sort)` is at
`/home/lox/code/_fcl/rookery/core/0.1.0/src/pure.typ:238-254`. Its date branch
reads, today:

```typ
  let stamp-of(id) = {
    let m = reg.at(id).at("created", default: none)
    if m == none { none } else { m.display("[year][month][day]") }
  }
  let dated = by-id.filter(id => stamp-of(id) != none)
  let undated = by-id.filter(id => stamp-of(id) == none)
  let ordered = ()
  for s in dated.map(stamp-of).dedup().sorted().rev() {
    ordered += dated.filter(id => stamp-of(id) == s)
  }
  ordered + undated
```

`stamp-of` does a dictionary lookup and a `datetime.display` call. It is called
once per id in each of the two filters, once per id in the `.map`, and then once
per dated id for EVERY distinct date in the corpus — so for N ids across D
distinct dates the count is `3N + N·D`. On a window selecting eighty dated notes
spread over sixty dates that is nearly five thousand `display` calls to produce
one ordering.

The ordering itself is correct and must not change. Its two guarantees, both
stated in the banner at `src/pure.typ:228-237` and asserted by the unit fixture:
dates descending, and within one date the ids ASCENDING; undated notes last.
Dates are compared as zero-padded `[year][month][day]` strings deliberately, to
avoid depending on how `datetime` orders as a sort key — keep that.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Decisions already made — do not re-derive

- **Keep the grouping, drop the recomputation.** The banner explains why this is
  not written as a single `.sorted(key: ..)`: Typst does not document
  `array.sorted` as stable, so a sort-by-id-then-sort-by-date pipeline cannot be
  relied on to keep the id order within a date. That reasoning still holds. Do
  not replace the grouping with a comparator.
- **Group through a dictionary keyed by stamp**, walked in `.keys().sorted().rev()`
  order. Because `dated` is built from `by-id` (already ascending) and dictionary
  insertion appends, each bucket comes out id-ascending for free — the same
  property the current `filter` relies on — and the explicit `.sorted()` on the
  keys means nothing depends on dictionary key order.

## Steps

1. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/pure.typ`, replace the body of
   `_sort-ids` after the `if sort != "date" { return by-id }` line with:

   ```typ
     // One `display()` per id: formatting the datetime is the cost here, and the
     // grouping below would otherwise redo it once per id per distinct date.
     let stamp-of(id) = {
       let m = reg.at(id).at("created", default: none)
       if m == none { none } else { m.display("[year][month][day]") }
     }
     let buckets = (:)
     let undated = ()
     for id in by-id {
       let s = stamp-of(id)
       if s == none { undated.push(id) } else {
         buckets.insert(s, buckets.at(s, default: ()) + (id,))
       }
     }
     // Each bucket is already id-ascending — `by-id` is, and appending keeps it —
     // so a date-descending walk of the keys yields id-ascending ties.
     let ordered = ()
     for s in buckets.keys().sorted().rev() { ordered += buckets.at(s) }
     ordered + undated
   ```

2. Keep the function's comment banner (lines 228-237) in place. Adjust only the
   sentence that describes the mechanism if it now reads false — the claims
   about lexicographic vs date order, about sort stability, and about comparing
   dates as strings all remain true and must stay.

## Do NOT

- Do not change the function's name, signature, or the `lexicographic` branch.
- Do not change the observable ordering in any way.
- Do not touch anything else in `pure.typ`, and do not reword comments outside
  the `_sort-ids` block — a separate bird covers this file's comment prose.
- Do not edit `test/units.typ`.

## VERIFY

`test/units.typ` covers this function directly: lines 262-277 build a `_reg`
fixture and assert both orderings, including the ascending-id tie-break and
undated-last. So:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
```

Expected last line: `units OK`.

Then the two demos, both green today, since `#window(sort: "date")` is exercised
there:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
```

Expected last lines: `demo/pure OK`, `demo/rheo OK`.