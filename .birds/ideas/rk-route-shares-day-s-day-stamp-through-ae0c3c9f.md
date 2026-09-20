---
id: rk-route-shares-day-s-day-stamp-through-ae0c3c9f
short-id: ae
title: Route shares-day's day-stamp through _day-of
priority: 1
labels:
- chore-timeline-api
deps: []
closed: true
---
Touches: timeline/0.1.0/src/view.typ

## Background

`timeline/0.1.0/src/fragment.typ:62` defines `_day-of(d) = d.display("[year][month][day]")` as the single reusable day-stamp helper in this package — the fixed-width `[year][month][day]` string format that makes a projected date a free sort key. It is exported from `fragment.typ` and reachable in `view.typ` already, because `view.typ:28` does `#import "fragment.typ": *`.

`timeline/0.1.0/src/view.typ`'s `shares-day` closure, at lines 113-119, builds this same day-stamp inline instead of calling `_day-of`:

```typ
let shares-day(i) = {
  let d = dated.at(i).timestamp
  if not _has-time(d) { return false }
  let day = d.display("[year][month][day]")
  let others = dated.enumerate().filter(((idx, _)) => idx != i).map(((_, e)) => e.timestamp)
  others.any(o => o.display("[year][month][day]") == day)
}
```

Two of the four `.display("[year][month][day]")` calls (line 116, computing
`day`, and inside the `.any(...)` on line 118, computing each `o`'s stamp)
duplicate `_day-of` exactly. This is the one place in the package where the
day-stamp format still has two independent spellings, left over from before
`_day-of` existed as a shared helper.

## Fix

Replace both inline `.display("[year][month][day]")` calls in `shares-day`
(`timeline/0.1.0/src/view.typ:116` and `:118`) with calls to `_day-of`:

```typ
let shares-day(i) = {
  let d = dated.at(i).timestamp
  if not _has-time(d) { return false }
  let day = _day-of(d)
  let others = dated.enumerate().filter(((idx, _)) => idx != i).map(((_, e)) => e.timestamp)
  others.any(o => _day-of(o) == day)
}
```

No import changes needed — `_day-of` is already in scope via the existing
`#import "fragment.typ": *` at `view.typ:28`.

## Do NOT

- Do not change `_has-time`, `dated`, `past`, or `booked` — this bird is
  scoped to the two `.display(...)` call sites inside `shares-day` only.
- Do not touch `fragment.typ`'s `_day-of` or `_stamp-of` definitions.
- Do not widen the format string or change what counts as "the same day" —
  this is a literal substitution, not a behaviour change. The rendered
  output must be byte-identical before and after.

## VERIFY

1. `rg -n '"\[year\]\[month\]\[day\]"' timeline/0.1.0/src/view.typ` — must
   return nothing after the fix (both call sites now go through `_day-of`).
2. `cd timeline/0.1.0 && just test` — must print `units OK` and `views OK`,
   unchanged from before your edit.
3. `cd todos/0.1.0 && just check` — must print `demo/rheo OK`. `view.typ`'s
   `shares-day` affects the rendered timeline-view HTML, which the todos
   demo also exercises; this confirms no visible output changed.
4. `bd status <this-bird's-id>` — `in_flight` until you alight, `retired`
   after.