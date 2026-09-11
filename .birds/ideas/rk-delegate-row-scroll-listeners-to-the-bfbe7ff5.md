---
id: rk-delegate-row-scroll-listeners-to-the-bfbe7ff5
short-id: bf
title: Delegate row-scroll listeners to the deck
priority: 3
labels:
- chore-slipshow-review
deps: []
closed: false
---
Replace N per-row `scroll` listeners with one delegated listener on the deck
in `@rookery/slipshow`'s controller. `init()` in `src/slipshow.js` currently
attaches a separate `scroll` listener to every `.slip-row` element in the
deck — a deck with twenty rows attaches twenty listeners, all doing the same
thing (`redrawEdges`). One capturing listener on `deck` answers the same
question with one listener instead of N, and does not miss anything: a
`scroll` event does not bubble, but a listener registered with
`{ capture: true }` still fires for it, because the capture phase runs top-down
from the document to the event's target regardless of whether that event
bubbles afterward — capture does not depend on bubbling.

Touches: /home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slipshow.js

## Where

`/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slipshow.js`, function
`init`, lines 378-382:

```js
  // A row scrolling sideways moves its slides' rails under curves anchored
  // outside it, and a row's scroll reaches no other listener here.
  for (const row of deck.querySelectorAll(".slip-row")) {
    row.addEventListener("scroll", redrawEdges, { passive: true });
  }
```

`redrawEdges` (lines 219-221) takes no arguments and reads no information off
the event — it always calls `redraw(deck)`, the same whole-deck rebuild
regardless of which row scrolled. That means the per-row wiring buys nothing
functional: every one of the N listeners, whichever row fires it, does the
exact same thing.

## Decisions already made — do not re-derive

- Delegate with ONE listener registered on `deck` itself, using
  `{ capture: true, passive: true }`. `capture: true` is load-bearing: a
  `scroll` event fired on a `.slip-row` element does not bubble to `deck`, so
  a bubble-phase listener on `deck` (the default, `capture` unset or `false`)
  would never see it. A capture-phase listener DOES see it, because capture
  runs on the way DOWN to the event's target, before Bubble phase would even
  start — it does not require the event to bubble afterward. `passive: true`
  is kept because nothing in the handler calls `preventDefault()`, matching
  the per-row version's own flag.
- The handler stays `redrawEdges` itself, unchanged — no need to check
  `event.target` or filter by `.slip-row`, because `redrawEdges()` already
  does the same whole-deck rebuild no matter which row (or the window)
  scrolled, and there is no cheaper per-row-scoped alternative to fall back
  to.
- This listener is added ONCE, in `init()`, at the same point in the
  function where the per-row loop currently sits — it does not need to be
  re-added when the DOM changes, because it is bound on `deck` itself, which
  `init()` already holds a stable reference to for the lifetime of the page.

## Steps

1. In `init()`, delete the `for (const row of deck.querySelectorAll(".slip-row")) { ... }` loop (lines 380-382).
2. In its place, add one line:

   ```js
   deck.addEventListener("scroll", redrawEdges, { capture: true, passive: true });
   ```

3. Update the comment above it (currently "A row scrolling sideways moves its
   slides' rails under curves anchored outside it, and a row's scroll
   reaches no other listener here.") to explain the delegation instead of the
   per-row loop it used to justify — keep the present-tense explanation of
   WHY this listener exists (a row scrolling sideways moves its rails under
   the curves anchored outside it) and add WHY `capture: true` is required
   (a `.slip-row`'s `scroll` event does not bubble to `deck`, so only a
   capture-phase listener on an ancestor sees it).

## Do NOT

- Do not change `redrawEdges()`, `onResize()`, or any other listener
  registration in `init()` (`keydown` on `document`, `click` on `deck`,
  `resize` on `window`) — only the per-row scroll wiring changes.
- Do not add a `.slip-row` existence check before registering the listener —
  registering it unconditionally on `deck` is correct even for a deck with
  no rows at all (it simply never fires), exactly as the current per-row
  loop already does nothing on such a deck.
- Do not try to filter by `event.target.closest(".slip-row")` inside the
  handler — that adds a DOM walk this fix exists to reduce, for no
  behavioural benefit, since `redrawEdges()` ignores its argument already.

## VERIFY

1. JS suite green — no existing test in `test/*.test.mjs` exercises
   `init()` or DOM event wiring directly (they test the pure functions in
   `camera.js`/`edges.js` and the reveal/entry logic in `slipshow.js`), so
   this is a regression check rather than new coverage:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test-js
   ```

   Expect all tests passing, `fail 0`.

2. Real-browser behaviour is exercised only by the demo/example builds
   (there is no headless-DOM test harness in this package), so confirm the
   build still succeeds:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just check
   ```

   Expect `demo/rheo OK`.

3. If any example under `examples/` uses `row:` to group slips into a
   `.slip-row` with connector edges (check for `row:` and `edges:` used
   together in `examples/*/content/*.typ` before assuming one does), run:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just examples
   ```

   Expect every `==> examples/*` line to complete with no error.