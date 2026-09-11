---
id: rk-compute-an-edge-target-s-box-once-f5af57a0
short-id: f5
title: Compute an edge target's box once
priority: 4
labels:
- chore-slipshow-review
deps: []
closed: false
---
Stop recomputing a slip's on-page geometry once per INCOMING edge in
`@rookery/slipshow`'s connector layer. `collect()` in `src/edges.js` measures
a `target` slide's box with `deckBox(target, deck)` inside a loop over that
same target's `data-slip-edges` ids — so a slide with three incoming edges
(three sources pointing at it) gets `deckBox` called on it three times,
recomputing the identical answer each time. `deckBox` walks the
`offsetParent` chain (reading `offsetLeft`/`offsetTop` node by node) and also
walks up through any `.slip-row` ancestors reading `scrollLeft`/`scrollTop` —
real DOM geometry reads, not free — and `redraw()` (the only caller of
`collect()`) already rebuilds the WHOLE connector layer on every reveal
change, resize, and row scroll, so this repeats on every one of those too.

Touches: /home/lox/code/_fcl/rookery/slipshow/0.1.0/src/edges.js

## Where

`/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/edges.js`, function
`collect`, lines 119-149:

```js
function collect(deck) {
  const edges = [];
  for (const target of deck.querySelectorAll("section.slip[data-slip-edges]")) {
    if (target.offsetParent === null) continue;
    const targetRail = rail(target);
    if (targetRail.width === 0) continue;
    const targetRow = target.closest(".slip-row");

    for (const id of target.dataset.slipEdges.split(/\s+/).filter(Boolean)) {
      // `getElementById`, not a `#id` selector: a slide's id carries the
      // note's registry prefix (`slip-idea:intro`) and a bare `:` in a
      // selector is a pseudo-class.
      const source = document.getElementById(id);
      if (!source || !deck.contains(source) || source.offsetParent === null) continue;
      const sourceRail = rail(source);
      if (sourceRail.width === 0) continue;
      const sourceRow = source.closest(".slip-row");
      if (sourceRow !== null && sourceRow === targetRow) continue;

      const sourceBox = deckBox(source, deck);
      const targetBox = deckBox(target, deck);
      edges.push({
        from: { x: railX(sourceBox, sourceRail.width), y: sourceBox.y + sourceBox.height },
        to: { x: railX(targetBox, targetRail.width), y: targetBox.y },
        fromColor: sourceRail.color,
        toColor: targetRail.color,
      });
    }
  }
  return edges;
}
```

`target`, `targetRail` and `targetRow` are already computed ONCE per outer
loop iteration, ahead of the inner `for (const id of ...)` loop — that
pattern is already right. `targetBox = deckBox(target, deck)` is the one
value in the inner loop that does NOT depend on `id` or `source` at all, yet
it is recomputed on every iteration of that inner loop, i.e. once per
incoming edge rather than once per target.

## Decisions already made — do not re-derive

- Hoist `targetBox` out of the inner loop, computed once right after
  `targetRow`, alongside the other per-target values.
- `sourceBox = deckBox(source, deck)` stays exactly where it is, inside the
  inner loop — it DOES depend on `source`, which changes every iteration, so
  there is nothing to hoist there.
- Do not memoize `deckBox` more broadly (e.g. a cache keyed by element) —
  the outer loop already visits each `target` exactly once, so hoisting
  within one iteration is the whole fix; a cross-call cache would add
  invalidation complexity `redraw()`'s own whole-rebuild discipline
  (documented in its own comment, lines 163-168) is deliberately designed to
  avoid.

## Steps

1. In `collect()`, move `const targetBox = deckBox(target, deck);` up so it
   sits beside `const targetRow = target.closest(".slip-row");` (i.e.
   computed once per `target`, before the inner `for (const id of ...)`
   loop), and delete the `const targetBox = deckBox(target, deck);` line
   that currently sits inside the inner loop.
2. The inner loop's `edges.push({ ... to: { x: railX(targetBox, ...), y:
   targetBox.y }, ... })` reference is unchanged — it already reads the
   `targetBox` variable by name, which now resolves to the hoisted one.

## Do NOT

- Do not change `rail()`, `railX()`, `edgePath()`, `ensureLayer()`, or
  `redraw()` — only `collect()`'s internal ordering changes.
- Do not change the drop conditions (`offsetParent === null`, zero rail
  width, same-row source/target) — their order and meaning are unaffected by
  where `targetBox` is computed.
- Do not touch `camera.js` — it has no DOM access at all (see its own file
  header) and this bird's finding does not apply there.

## VERIFY

1. JS suite green — `test/edges.test.mjs` exercises `edgePath`/`railX`
   directly (pure functions, no DOM), so it does not observe `collect()`'s
   internals, but it must still pass with no changes:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test-js
   ```

   Expect all tests passing, `fail 0`.

2. The rendered connector layer is unchanged — verify with the real DOM
   build:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just check
   ```

   Expect `demo/rheo OK`. If `examples/dag` (which specifically exercises
   `edges:`) is relevant to double-check, also run:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just examples
   ```

   Expect every `==> examples/*` line to complete with no error, and any
   example carrying its own `check.sh` to print its own `OK` line.