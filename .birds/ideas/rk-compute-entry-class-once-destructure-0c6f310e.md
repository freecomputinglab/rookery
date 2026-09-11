---
id: rk-compute-entry-class-once-destructure-0c6f310e
short-id: 0c6
title: Compute entry class once, destructure gradient stops
priority: 2
labels:
- chore-slipshow-review
deps: []
closed: false
---
Two small idiom fixes in one file of `@rookery/slipshow`. Neither changes
behaviour.

Touches: /home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slipshow.typ

## Fix 1 — `_entry-class` called twice for one answer

`_slip-attrs`, lines 325-332:

```typ
#let _slip-attrs(e, i, id-of: (:)) = {
  let id = if e.kind == "row" { "slip-" + e.row.id } else { "slip-" + str(i) }
  let cls = (
    "slip",
    ..if is-fullscreen(e.tags) { ("slip-fullscreen",) } else { () },
    ..if _entry-class(e) != none { (_entry-class(e),) } else { () },
  )
```

`_entry-class(e)` is called twice in that one line — once to test it against
`none`, once to use the value. `_entry-class` (lines 293-301) is a plain
function of `e` with no side effects, so the second call recomputes an
answer already in hand.

Fix: bind it once, ahead of `cls`:

```typ
  let entry-class = _entry-class(e)
  let cls = (
    "slip",
    ..if is-fullscreen(e.tags) { ("slip-fullscreen",) } else { () },
    ..if entry-class != none { (entry-class,) } else { () },
  )
```

## Fix 2 — destructure a `(color, ratio)` pair instead of `.at(0)`/`.at(1)`

`_gradient-css`, line 185:

```typ
  let stops = g.stops().map(p => p.at(0).to-hex() + " " + repr(p.at(1))).join(", ")
```

`g.stops()` returns an array of two-element arrays, each `(color, ratio)`.
Indexing both halves by position reads worse than destructuring the pair in
the closure's own parameter list, which is the idiom this package already
uses for a two-element pair elsewhere (`select.typ`'s `_sort-pairs` takes
`(key: .., row: ..)` records and reads them by field name rather than by
position, for the same reason).

Fix:

```typ
  let stops = g.stops().map(((c, r)) => c.to-hex() + " " + repr(r)).join(", ")
```

## Do NOT

- Do not change `_gradient-css`'s three branches (`linear`/`radial`/`conic`)
  beyond the one `.map()` line above — the angle-correction and colour-space
  logic is unrelated to this fix.
- Do not touch `_background-style`, `_background-child`, `_check-background`,
  or `_max-width-style` — each of those already reads its input exactly
  once per call; the duplication in this bird is scoped to the two spots
  named above only.
- Do not change `_slip-attrs`'s parameter list or its two direct call sites
  in `/home/lox/code/_fcl/rookery/slipshow/0.1.0/test/units.typ` (lines 372
  and 377, which call it with its current three arguments) — Fix 1 only
  reorders WHERE `_entry-class(e)` is called, it does not change
  `_slip-attrs`'s signature at all.

## VERIFY

1. Typst suite green — `test/units.typ` calls `_slip-attrs` directly (lines
   372, 377) and exercises class-list output elsewhere, and gradient
   backgrounds are covered by the demo/example fixtures below rather than by
   `test/units.typ`:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test
   ```

   Expect `units OK`.

2. Negative suite unaffected:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && bash test/panics.sh
   ```

3. Full build check:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just check
   ```

   Expect `demo/rheo OK`.

4. `examples/backgrounds` is the fixture that renders a gradient background
   through `_gradient-css`, so it is the one that would catch a mistake in
   Fix 2:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just examples
   ```

   Expect every `==> examples/*` line, `examples/backgrounds` included, to
   complete with no error.