---
id: rk-drag-a-pinboard-card-by-its-handle-1d0aa913
short-id: 1d
title: Drag a pinboard card by its handle
priority: 4
labels:
- feat-pinboard
deps:
- blocked-by:rk-scaffold-rookery-pinboard-c9b5e67f
closed: true
---
A pinboard's whole point is that the author moves the cards. This bird makes a card
draggable by its handle.

It depends on `@rookery/pinboard` already existing as a package with a board that
renders. That is bird `rk-scaffold-rookery-pinboard-c9b5e67f`, and rather
than send you to read it, here is everything from it you need:

- The package lives at `/home/lox/code/_fcl/rookery/pinboard/0.1.0/`.
- `src/board.typ` emits `<div class="pinboard" data-pinboard="<board id>">` containing
  one `<article class="pinboard-card" data-pinboard-id="<idea id>">` per note, each
  holding a `<header class="pinboard-card-handle">` with the note's title and a
  `<div class="pinboard-card-body">` with its prose.
- `src/pinboard.js` is vite's entry and the boot module. On load it finds every
  `[data-pinboard]`, computes a flow layout with `flowPositions` from
  `src/layout.js`, and writes each card's place as two CSS custom properties,
  `--pin-x` and `--pin-y`, which `src/pinboard.css` consumes via
  `translate: var(--pin-x, 0) var(--pin-y, 0)` on an absolutely positioned card.
- `typst.toml` carries a `[tool.rheo.source.html]` block whose `js_scripts` array
  lists the unbundled ES modules DEPENDENCY-FIRST. rheo's asset copy acts on exactly
  that list rather than scanning imports, so a new module missing from it is simply
  absent from the output of a git-ref build, with no error anywhere.

Touches: pinboard/0.1.0/src/drag.js, pinboard/0.1.0/src/pinboard.js, pinboard/0.1.0/src/pinboard.css, pinboard/0.1.0/typst.toml, pinboard/0.1.0/test/drag.test.mjs

## Steps

1. **Write `src/drag.js`**, exporting one function:

   ```js
   export function makeDraggable(board, opts)
   ```

   `board` is a `[data-pinboard]` element. The function wires ONE set of listeners on
   the board itself and lets events from the cards bubble up to it, rather than
   attaching a listener per card. There can be a hundred cards on a board and a card
   is added or removed only by a rebuild, so a delegated listener is both cheaper and
   simpler to reason about.

2. **Use Pointer Events, not mouse events.** On `pointerdown` on the board:

   - Find the handle with `event.target.closest(".pinboard-card-handle")`. If there
     is none, return — a drag begins on the handle and nowhere else, so text in the
     card body stays selectable.
   - Return also if the press landed on an interactive descendant of the handle:
     `event.target.closest("a, button, input, summary")`. The card title IS a link to
     the note's own page, and a drag implementation that swallows that click breaks
     the board's only navigation. This check is the reason the title stays clickable.
   - Return if `event.button` is anything other than 0, so a right-click or a
     middle-click does not start a drag.
   - Call `board.setPointerCapture(event.pointerId)`. Capture is what makes the drag
     survive the pointer leaving the card, leaving the board, or passing over another
     card mid-gesture — without it a fast drag drops the card wherever the pointer
     happened to exit.
   - Call `event.preventDefault()` to suppress the browser's native text-selection
     and image-drag behaviour.

3. **Track the grab offset, not the pointer position.** Record, at `pointerdown`, the
   card's current `--pin-x`/`--pin-y` and the pointer's `clientX`/`clientY`. On
   `pointermove`, the new position is the old position plus the pointer's delta.
   Setting the card's position to the raw pointer position instead makes the card
   jump so its top-left corner snaps under the cursor the instant a drag begins,
   which is the single most common way this gets written wrong.

4. **Clamp to the board.** A card's position is clamped so that `x` and `y` are never
   negative and the card's own width and height never carry it past the board's
   `scrollWidth`/`scrollHeight`. A card dragged to a negative coordinate is
   unreachable afterwards, because the board does not scroll into negative space.

5. **Raise the dragged card.** Set an incrementing `z-index` on the card being
   dragged, kept in a counter that lives on the board, so the most recently touched
   card is on top and stays there after the drag ends. Cards overlap; without this,
   dragging a card under another one makes it disappear.

6. **End the drag on `pointerup` and `pointercancel`,** releasing the pointer capture
   in both. `pointercancel` fires when the browser takes the gesture over — a
   touch turning into a scroll, for instance — and a handler that only listens for
   `pointerup` leaves the board stuck in a dragging state that only a reload clears.

7. **Mark the dragging state in the DOM.** Set `data-dragging` on the card for the
   duration of the gesture and remove it at the end. In `src/pinboard.css`, give
   `.pinboard-card[data-dragging]` `cursor: grabbing` and disable any transition on
   `translate`, so the card tracks the pointer exactly rather than easing behind it.

8. **Read and write positions through one pair of helpers.** Export from `drag.js`, or
   put in `layout.js` if you prefer them beside the flow layout, a
   `readPosition(card)` returning `{x, y}` parsed from the two custom properties and
   a `writePosition(card, x, y)` setting them. The bird chained behind this one
   persists positions and will call exactly these; a drag that writes
   `style.setProperty` inline in three places makes that bird a refactor instead of
   an addition.

9. **Call it from `src/pinboard.js`**: after computing the flow layout for a board,
   call `makeDraggable(board)` on it.

10. **Add `"src/drag.js"` to `[tool.rheo.source.html]`'s `js_scripts` array in
    `typst.toml`,** before `"src/pinboard.js"` and after `"src/layout.js"`. The list
    is dependency-first and rheo copies exactly what it names. Getting this wrong
    does not fail the build — it produces a git-ref consumer whose board renders and
    does not drag.

11. **Write `test/drag.test.mjs`** for the parts a node test can actually reach: the
    clamping arithmetic and the offset arithmetic, as pure functions with numbers
    passed in. Export them from `drag.js` so the test can import them.

    Be honest about the limit here, because it shapes the test: the suites in this
    repo run under node with `linkedom` standing in for a browser, and linkedom is a
    DOM object graph rather than an engine — no layout, no `getBoundingClientRect`,
    no pointer events, no real event dispatch. A test asserting that a simulated
    `pointerdown` moves a card would be asserting on linkedom, not on a browser. The
    gesture itself is covered by a separate bird that runs the pinboard under
    Playwright.

## Non-goals

- **No collapsing.** Next bird.
- **No persistence.** Positions are lost on reload, and that is correct for this bird.
  Do not add `localStorage`, and do not add a "save" call that writes nowhere.
- **No multi-select, no marquee selection, no dragging several cards at once.**
- **No resize handles, no z-order UI, no snapping or grid alignment.**
- **No touch-specific code paths.** Pointer Events already cover touch, pen and mouse
  in one API; adding a parallel `touchstart` path is how the two get out of sync.
- **Do not change `src/board.typ`.** The DOM this bird needs is already emitted.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/pinboard/0.1.0`:

1. `just build` succeeds.
2. `just test-js` passes, including the new `test/drag.test.mjs`.
3. `just check` succeeds — the demo still compiles and `check.sh` still exits zero.
4. `rg -n 'src/drag.js' typst.toml` shows it listed between `src/layout.js` and
   `src/pinboard.js`.
5. `rg -n 'closest\("a, button' src/drag.js` finds the guard that keeps the card
   title's link clickable.
6. `rg -n 'pointercancel' src/drag.js` finds the cancel handler.