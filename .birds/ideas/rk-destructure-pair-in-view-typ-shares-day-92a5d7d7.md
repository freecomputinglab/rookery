---
id: rk-destructure-pair-in-view-typ-shares-day-92a5d7d7
short-id: '92'
title: Destructure pair in view.typ shares-day
priority: 2
labels:
- chore-timeline-review
deps: []
closed: false
---
**Destructure the `(index, value)` pair in `view.typ`'s `shares-day` instead of indexing it with `.at(0)`/`.at(1)`.**

`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/view.typ`, inside
`#timeline-view` (starts line 47), the local helper `shares-day` at lines
111-117:

```typ
  let shares-day(i) = {
    let d = dated.at(i).timestamp
    if not _has-time(d) { return false }
    let day = d.display("[year][month][day]")
    let others = dated.enumerate().filter(p => p.at(0) != i).map(p => p.at(1).timestamp)
    others.any(o => o.display("[year][month][day]") == day)
  }
```

Line 115 calls `.enumerate()`, which produces an array of `(index, value)`
pairs, then reaches into each pair with `p.at(0)` (the index) and `p.at(1)`
(the value) inside two separate closures. Typst supports destructuring a
tuple parameter directly in a closure's parameter list — `((idx, val)) =>
..`, with `_` for the half that is unused — and this repo already uses that
spelling elsewhere (e.g. `fragment.typ`'s `_timeline-entries`: `let (i, pair)
= p` followed by `let (stage, given) = pair`, and this same file's own
`row(..)` helper does not need it but the pattern is standard elsewhere in
`@rookery/core` and `@rookery/search`). `.at(0)`/`.at(1)` on a pair is
harder to read than naming the two halves, and this file is the one place in
`@rookery/timeline` that still spells it that way.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/view.typ

## Decisions already made — do not re-derive

- Rewrite ONLY line 115. The rest of `shares-day` (lines 111-114, 116) and
  every other line in this file stay exactly as they are.
- The `.filter(..)` half only needs the index, and the `.map(..)` half only
  needs the value — so the filter's destructured pair should discard its
  second element and the map's destructured pair should discard its first,
  using `_` for the discarded half, matching this repo's own convention
  (`bird-quality`'s example: `.map(((k, v)) => ..)`, with `_` for an unused
  half).
- Do not rename `i` (the outer parameter of `shares-day`) — it is used
  elsewhere in the function (line 112, `dated.at(i)`) and at every call site
  (lines 127, 182, 198).

## Steps

1. Open `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/view.typ`.
2. Replace line 115:

   ```typ
   let others = dated.enumerate().filter(p => p.at(0) != i).map(p => p.at(1).timestamp)
   ```

   with:

   ```typ
   let others = dated.enumerate().filter(((idx, _)) => idx != i).map(((_, e)) => e.timestamp)
   ```

3. Leave every other line in the file untouched.

## Do NOT

- Do not touch `row(..)` (lines 143-170), the `happened(e)` closure (lines
  69-75), or any other closure in this file — none of them index a pair with
  `.at(0)`/`.at(1)`, so none of them need this change.
- Do not touch any other file in this package.
- Do not change the behaviour of `shares-day` — this is a pure rewrite of how
  the pair is unpacked, not a change to what the function returns.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test
```

Must print exactly what it prints on the unmodified package: `units OK`,
then the two HTML exports (only the existing "html export is under active
development" warnings), then `check.sh`'s summary lines ending `views OK`,
including the unchanged line `timeline-view: 8 rails, one current row each,
divider only where both sides exist, same-day times activated/closed, 1
expected rung with a ladder and 0 without` — the "same-day times" clause is
exactly what `shares-day` decides, so any behaviour change here would change
that line or fail an assertion in `test/units.typ`.