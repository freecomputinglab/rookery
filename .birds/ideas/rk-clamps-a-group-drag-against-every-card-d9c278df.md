---
id: rk-clamps-a-group-drag-against-every-card-d9c278df
short-id: d9
title: Clamps a group drag against every card at once
priority: 3
labels:
- fix-pinboard-group-clamp-order
deps: []
closed: true
---
`clampGroupDelta` narrows a group drag's delta one card at a time, interleaving
the left bound and the right bound, so when no delta can satisfy every card the
answer depends on the order the cards happen to arrive in — and whichever order
it is, one card ends up off the board.

Touches: pinboard/0.1.0/src/drag.js, pinboard/0.1.0/test/drag.test.mjs

## The defect

`pinboard/0.1.0/src/drag.js:104-113` is:

```js
export function clampGroupDelta(items, delta, boardWidth) {
  let dx = delta.x;
  let dy = delta.y;
  for (const item of items) {
    dx = Math.max(dx, -item.x);
    dx = Math.min(dx, boardWidth - item.width - item.x);
    dy = Math.max(dy, -item.y);
  }
  return { x: dx, y: dy };
}
```

Each iteration raises `dx` to clear this card's left bound, then lowers it to
respect this card's right bound. A later card's `Math.min` can therefore undo an
earlier card's `Math.max`, and vice versa. The bounds only conflict when the
group's own horizontal extent is wider than the board, but that is reachable: a
card's stored position is restored as-is, so a board arranged in a wide window
and reopened in a narrow one has cards sitting beyond the board's current width.

WORKED EXAMPLE, both orders, with `boardWidth = 1200` and `delta.x = -50`:

- items `[{x: 0, width: 100}, {x: 1150, width: 100}]` → returns `dx = -50`.
  The first card lands at `x = -50`, off the LEFT edge.
- the same two items in the other order → returns `dx = 0`. The second card
  stays at `x = 1150`, its right edge at 1250, off the RIGHT edge.

So the function is order-dependent, and neither order is correct.

## The fix, and the tie-break it needs

Gather the bounds across ALL items first, then clamp the delta once. That is
the whole change; it is three accumulators instead of two mutations.

Where the bounds genuinely conflict, there is no satisfying delta and the
function has to prefer one edge. **Prefer the left bound** — keep the group's
leftmost card at or right of `x = 0`, and let the right-hand overflow stand. A
card at a negative `x` is permanently unreachable: the board does not scroll
leftward and there is no gesture that can grab what is off that edge. A card
past the right edge is the state a too-wide group is already in at rest, and it
remains draggable.

## Steps

1. In `pinboard/0.1.0/src/drag.js`, replace the body of `clampGroupDelta`
   (lines 104-113) with a two-pass version:

   ```js
   export function clampGroupDelta(items, delta, boardWidth) {
     let minDx = -Infinity;
     let maxDx = Infinity;
     let minDy = -Infinity;
     for (const item of items) {
       minDx = Math.max(minDx, -item.x);
       maxDx = Math.min(maxDx, boardWidth - item.width - item.x);
       minDy = Math.max(minDy, -item.y);
     }
     // A group wider than the board cannot satisfy both bounds at once, and
     // the left one wins: a card at a negative `x` cannot be reached again,
     // where one past the right edge is still draggable.
     const ceilingDx = Math.max(maxDx, minDx);
     return {
       x: Math.min(Math.max(delta.x, minDx), ceilingDx),
       y: Math.max(delta.y, minDy),
     };
   }
   ```

   An empty `items` array leaves every accumulator infinite and the delta
   unchanged, which is the right answer and needs no special case.

2. Rewrite the comment above `clampGroupDelta` (currently lines 98-103). It
   should say that the bounds are gathered across every card before the delta
   is clamped once, because clamping per card lets one card's bound undo
   another's; that only `dx` has an upper bound, the board's height following a
   downward drag; and which edge wins when the group is wider than the board.
   Follow `CLAUDE.md`'s comment rules — present tense, no history, no issue id,
   and do not narrate the arithmetic the code already shows.

3. Add two tests to `pinboard/0.1.0/test/drag.test.mjs`, after the existing
   `clampGroupDelta` cases (which end at line 118 with the upward-delta case;
   a further downward-delta case begins at line 120 — put these after that
   one). Use the file's existing style: `node:test`, `node:assert` strict,
   plain object literals, no helpers.

   ```js
   test("clampGroupDelta is independent of the order its members arrive in", () => {
     const a = { x: 0, y: 0, width: 100 };
     const b = { x: 1150, y: 0, width: 100 };
     const forward = clampGroupDelta([a, b], { x: -50, y: 0 }, 1200);
     const reversed = clampGroupDelta([b, a], { x: -50, y: 0 }, 1200);
     assert.deepEqual(forward, reversed);
   });

   test("clampGroupDelta keeps the leftmost member on the board when the group is too wide for it", () => {
     const items = [
       { x: 0, y: 0, width: 100 },
       { x: 1150, y: 0, width: 100 },
     ];
     const delta = clampGroupDelta(items, { x: -50, y: 0 }, 1200);
     assert.equal(delta.x, 0);
     assert.ok(items[0].x + delta.x >= 0);
   });
   ```

4. Check the four existing `clampGroupDelta` tests still pass unchanged (they
   begin at line 88 with the in-bounds case). They should: none of them uses a
   group wider than the board, so the two-pass version returns exactly what the
   interleaved one did. If one of them DOES change, stop and report which —
   that would mean the old behaviour was load-bearing somewhere this bird has
   not accounted for.

## Non-goals

- Do NOT give `dy` an upper bound. A drag downward is how the board is made
  taller and `src/pinboard.js`'s `growBoardFor` follows it; a ceiling here
  would undo that.
- Do NOT change `clampPosition` or `offsetPosition`
  (`src/drag.js:67-96`), their comments, or their tests.
- Do NOT change `makeDraggable`'s `pointermove` handler, or how it builds the
  `items` array it passes in.
- Do NOT add horizontal scrolling or let the board grow sideways.
- Do NOT create a new version directory; this is a fix to the shipped
  `pinboard/0.1.0`.
- Do NOT add a changelog entry — the package has none.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/pinboard/0.1.0 && just test-js` — reports
   `fail 0`, and the two new test names appear in the output.
2. `cd /home/lox/code/_fcl/rookery/pinboard/0.1.0 && just check` passes (vite
   build, `rheo compile`, and `demo/rheo/check.sh`).
3. `cd /home/lox/code/_fcl/rookery/pinboard/0.1.0 && node test/browser/board.mjs`
   prints `ok pinboard-board` for webkit, chromium and firefox. This file is
   NOT wired into any `Justfile` target, so it has to be run by name.
4. `rg -n 'dx = Math.min' /home/lox/code/_fcl/rookery/pinboard/0.1.0/src/drag.js`
   returns NOTHING — the interleaved narrowing is gone.