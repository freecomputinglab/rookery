---
id: rk-marquee-selects-cards-and-drags-them-as-8e861d89
short-id: 8e
title: Marquee-selects cards and drags them as one
priority: 2
labels:
- feat-pinboard-marquee-select
deps:
- blocked-by:rk-lets-a-drag-extend-the-board-downward-23eac6b6
closed: true
---
A pinboard can only be rearranged one card at a time. Moving a cluster of
related notes means dragging each of them and eyeballing the spacing. This
adds a rubber-band (marquee) selection over the empty space of the board and
makes a drag on any selected card move the whole selection together.

The gesture contract, in full:

- A press on the board's empty space — anywhere not inside a `.pinboard-card`
  — clears the current selection immediately, and then, once the pointer has
  moved past the drag threshold, draws a marquee rectangle from the press
  point to the pointer. On release, every card whose own rectangle overlaps
  the marquee at all (overlap, not containment) becomes selected.
- A press on the summary row of a card that IS selected drags every selected
  card, preserving their relative offsets.
- A press on the summary row of a card that is NOT selected clears the
  selection and drags that card alone, exactly as today.
- A press that does not move far enough to be a drag is still a click: on a
  selected card it opens or closes that card and LEAVES the selection alone;
  on empty space or an unselected card it has already cleared the selection,
  which is the "clicking once anywhere that is not a selected handle
  deselects" rule.

## What the code looks like now

- `pinboard/0.1.0/src/drag.js` — `makeDraggable(board, opts)` at line 82 wires
  one delegated set of pointer listeners on the board. `pointerdown`
  (108-130) requires the press to land on
  `[data-rookery="window-summary"]` (the `HANDLE` constant, line 31), ignores
  presses on `a, button, input`, and builds a single-card `drag` object
  `{ card, start, startPointer, pointerId, moved }`. `pointermove` (132-151)
  crosses `DRAG_THRESHOLD` (3px, line 34), sets `card.dataset.dragging`, takes
  pointer capture, and writes `clampPosition(offsetPosition(..))`. `endDrag`
  (153-162) releases capture, arms the click suppressor, and calls
  `opts.onChange?.(card)`.
- `pinboard/0.1.0/src/pinboard.js` — boot module. `layOutBoard` ends by
  calling `makeDraggable(board, { onChange: persist, .. })` at line 113 and
  `makeCollapsible(board, { onChange: persist })` at line 114. `persist(card)`
  (lines 52-60) writes one card's `{x, y, collapsed}` through
  `src/store.js`'s `saveCard` and re-measures the board.
- A card's position is the `--pin-x`/`--pin-y` custom property pair, read and
  written by `readPosition`/`writePosition` in `src/drag.js:36-46`, never
  `style.left`/`style.top`.
- **Board-relative coordinates are free.** `.pinboard` is `position: relative`
  with no padding and `.pinboard-card` is `position: absolute` with no
  `left`/`top`, offset purely by `translate: var(--pin-x) var(--pin-y)`
  (`pinboard/0.1.0/src/pinboard.css:20-30`). So a card's rectangle in board
  coordinates is exactly
  `{ x: readPosition(card).x, y: readPosition(card).y, width: card.offsetWidth, height: card.offsetHeight }`
  — no `getBoundingClientRect` needed for the hit test.
- `pinboard/0.1.0/typst.toml` has a `[tool.rheo.source.html]` block listing
  every `src/*.js` file as an ES module, dependency-first. A new module must
  be added to it or a project resolving this package off a git ref will not
  load it.

## Design decisions already made — implement these, do not reconsider

- **Selection lives in the DOM, not in a JavaScript set.** A selected card
  carries a `data-selected` attribute, and "the selection" is always
  `board.querySelectorAll('.pinboard-card[data-selected]')`. One source of
  truth, stylable from CSS, and it lets `drag.js` read the selection without
  importing the selection module (which would import `drag.js` back for
  `readPosition`).
- **A new module, `src/select.js`**, holds the marquee. It owns the pure
  geometry (`marqueeRect`, `rectsOverlap`), the selection accessors, and
  `makeSelectable(board)` which wires the marquee's own pointer listeners.
  `src/drag.js` keeps the card-dragging gesture and only *reads* the
  selection. A new module rather than more lines in `drag.js` because the two
  gestures start on different targets and share nothing but the board.
- **The group is clamped by clamping the delta, not each card.** Clamping
  members independently deforms the group the moment one of them reaches
  x=0. So the drag computes one `(dx, dy)` for the gesture, narrows it until
  every member stays in bounds, and applies the same pair to all.
- **`opts.onChange` fires once per moved card** at the end of a group drag,
  because `pinboard.js`'s `persist` is written per card and each member needs
  its own store entry.
- **Selection is not persisted.** It is a transient gesture state, not part of
  the arrangement; `src/store.js` and the stored entry shape do not change.

Touches: pinboard/0.1.0/src/select.js, pinboard/0.1.0/src/drag.js, pinboard/0.1.0/src/pinboard.js, pinboard/0.1.0/src/pinboard.css, pinboard/0.1.0/typst.toml, pinboard/0.1.0/test/select.test.mjs, pinboard/0.1.0/test/drag.test.mjs

## Steps

1. Create `pinboard/0.1.0/src/select.js`. Open it with a header comment in
   this repo's style (see `src/collapse.js:1-10` for the register): what the
   module is, that selection is the `data-selected` attribute on a card so
   the DOM is the single source of truth and `src/drag.js` can read it
   without an import, and that a card's rectangle is its `--pin-x`/`--pin-y`
   pair plus its offset size because `.pinboard` is the cards' own
   coordinate space. Export:

   ```js
   // The marquee's rectangle from the two pointer positions it was dragged
   // between, in board coordinates. Normalized, so a drag up-and-left is the
   // same rectangle as the drag down-and-right that traces it backwards.
   export function marqueeRect(start, pointer) { .. }   // -> { x, y, width, height }

   // Any overlap counts, not containment: a reader dragging a band across a
   // column of cards means the ones it crossed, not only the ones it managed
   // to swallow whole. Edge-touching does not count.
   export function rectsOverlap(a, b) { .. }            // -> boolean

   // A card's rectangle in board coordinates.
   export function cardRect(card) { .. }                // -> { x, y, width, height }

   export function selectedCards(board) { .. }          // -> Card[] in document order
   export function isSelected(card) { .. }
   export function setSelected(card, selected) { .. }   // toggles `data-selected`
   export function clearSelection(board) { .. }

   export function makeSelectable(board, opts = {}) { .. }
   ```

   `cardRect` must use `readPosition` imported from `./drag.js` plus
   `card.offsetWidth`/`card.offsetHeight`. `rectsOverlap` is
   `a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height`.

2. Implement `makeSelectable(board, opts)` in the same file, as one delegated
   `pointerdown` on the board plus `pointermove`/`pointerup`/`pointercancel`:

   - On `pointerdown`: ignore anything but `event.button === 0`; return
     immediately if `event.target.closest('.pinboard-card')` is non-null (that
     press belongs to `drag.js`). Otherwise call `clearSelection(board)` and
     record `{ startPointer: { x, y } in board coordinates, pointerId, band: null }`.
     Board coordinates are `event.clientX - board.getBoundingClientRect().left`
     and the same for `y`/`top` — read the board's rect ONCE per gesture, at
     `pointerdown`, and keep it in the gesture state; reading it per
     `pointermove` is a forced layout per frame.
   - On `pointermove`, once `movedEnough(startPointer, pointer)` (import it
     from `./drag.js`) first returns true: create
     `<div class="pinboard-marquee">`, append it to `board`, and take
     `board.setPointerCapture(event.pointerId)`. On every subsequent move set
     the band's `style.left/top/width/height` from `marqueeRect` in pixels.
   - On `pointerup`: if a band exists, select every
     `board.querySelectorAll(':scope > .pinboard-card')` whose `cardRect`
     overlaps the final `marqueeRect`, then remove the band, release capture,
     and call `opts.onChange?.(selectedCards(board))` if a callback was given.
     If no band was created the press was a bare click and the selection was
     already cleared on `pointerdown` — nothing more to do.
   - On `pointercancel`: tear the band down and drop the gesture exactly as
     `pointerup` does but WITHOUT selecting anything, mirroring
     `drag.js:164-168`'s reason — a gesture the browser takes over must not
     leave the board stuck with a band on it.

3. In `pinboard/0.1.0/src/drag.js`, import the selection accessors at the top
   of the file, after the `HANDLE` constant:

   ```js
   import { selectedCards, isSelected, clearSelection } from "./select.js";
   ```

   Note for the implementer: `select.js` imports `readPosition` and
   `movedEnough` from `drag.js` while `drag.js` imports the selection
   accessors from `select.js`. This is a cycle, and it is fine under ES
   modules because every one of those bindings is only ever *called* at
   gesture time, never read at module-evaluation time. Do not try to break it
   by duplicating `readPosition`.

4. In `makeDraggable`'s `pointerdown` handler (`src/drag.js:108-130`), after
   the `const card = handle.closest(".pinboard-card"); if (!card) return;`
   lines, decide the drag's subject:

   ```js
   // A press on a selected card moves the whole selection; a press on an
   // unselected one is the "click anywhere that is not a selected handle"
   // that drops the selection, and then drags that card alone.
   let cards;
   if (isSelected(card)) {
     cards = selectedCards(board);
   } else {
     clearSelection(board);
     cards = [card];
   }
   ```

   Then replace the `drag` object with a group-shaped one:

   ```js
   drag = {
     cards,
     starts: cards.map((c) => readPosition(c)),
     startPointer: { x: event.clientX, y: event.clientY },
     pointerId: event.pointerId,
     moved: false,
   };
   for (const c of cards) c.style.zIndex = String(++topZ);
   ```

5. Add a pure helper to `src/drag.js`, exported and unit-tested, that narrows
   one delta so every member of the group stays in bounds:

   ```js
   // Narrows a drag's delta until every card in the group stays inside the
   // board, rather than clamping each card on its own — an independent clamp
   // deforms the group the moment one member reaches an edge, and the whole
   // point of a group drag is that the arrangement travels intact. Only `dx`
   // has an upper bound: the board's height follows a downward drag (see
   // `clampPosition`).
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

   `items` are `{ x, y, width }` objects — each card's START position and its
   width.

6. Rewrite `makeDraggable`'s `pointermove` body (`src/drag.js:132-151`) to
   move the group. Keep the existing threshold logic and pointer capture
   exactly as they are, but set `dataset.dragging` on every member, and
   replace the single-card position write with:

   ```js
   const items = drag.cards.map((c, i) => ({
     x: drag.starts[i].x,
     y: drag.starts[i].y,
     width: c.offsetWidth,
   }));
   const delta = clampGroupDelta(
     items,
     { x: pointer.x - drag.startPointer.x, y: pointer.y - drag.startPointer.y },
     board.scrollWidth,
   );
   drag.cards.forEach((c, i) => {
     writePosition(c, drag.starts[i].x + delta.x, drag.starts[i].y + delta.y);
     opts.onMove?.(c);
   });
   ```

   `clampPosition` and `offsetPosition` are no longer called from
   `pointermove`. Keep both exported — they are unit-tested and
   `clampPosition` still documents the board's coordinate rules — but if
   nothing calls `offsetPosition` any more, say so in one line of its comment
   rather than deleting it and its tests.

7. Rewrite `endDrag` (`src/drag.js:153-162`) for the group: clear
   `dataset.dragging` on every member, release capture once, arm the click
   suppressor once, and then call `opts.onChange?.(c)` for EACH card, so
   `pinboard.js`'s `persist` writes one store entry per moved card. A gesture
   that never moved still returns early without calling `onChange`, as today.

8. Update the `src/drag.js` header comment (lines 1-29) to describe the
   present shape: the handle is still the summary row, and a press on a
   SELECTED card drags every selected card with it while a press on an
   unselected one drops the selection first. Do not narrate the change.

9. In `pinboard/0.1.0/src/pinboard.js`: import `makeSelectable` from
   `./select.js` alongside the existing imports (line 22 area), and call it
   in `layOutBoard` next to the other two wirings at lines 113-114:

   ```js
   makeSelectable(board);
   ```

   Extend the module header's list of what it wires (lines 1-10) with the
   marquee selection from `src/select.js`.

10. Add the two rules to `pinboard/0.1.0/src/pinboard.css`, at the end of the
    file, each with a comment in the file's existing register:

    ```css
    /* A selected card is marked for the group drag a press on it will start.
       A ring rather than a fill: a card is transparent by default so the
       board's own ground shows through it, and a tint here would be the
       second ground the card deliberately does not have. */
    .pinboard-card[data-selected] {
      outline: 2px solid var(--pinboard-select, currentColor);
      outline-offset: 2px;
      border-radius: 2px;
    }

    /* The rubber band, appended to the board by `src/select.js` for the
       duration of a marquee drag and positioned in the board's own
       coordinate space — the same space the cards' `--pin-x`/`--pin-y` are
       in, since `.pinboard` is the positioned ancestor of both. Under the
       cards, and transparent to the pointer, so it never takes an event
       from the gesture drawing it. */
    .pinboard-marquee {
      position: absolute;
      z-index: 0;
      pointer-events: none;
      border: 1px dashed var(--pinboard-select, currentColor);
      background: color-mix(in srgb, var(--pinboard-select, currentColor) 8%, transparent);
    }
    ```

11. Add `"src/select.js"` to the `js_scripts` array in
    `[tool.rheo.source.html]` in `pinboard/0.1.0/typst.toml`. The array is
    dependency-first and `select.js` is imported by both `drag.js` and
    `pinboard.js`, so put it BEFORE `"src/drag.js"`:
    `["src/store.js", "src/layout.js", "src/select.js", "src/drag.js", "src/collapse.js", "src/pinboard.js"]`.

12. Create `pinboard/0.1.0/test/select.test.mjs`, in the shape of
    `test/drag.test.mjs` (a header comment saying these are the pure geometry
    halves, testable under `node --test` with no browser). Cover:
    `marqueeRect` normalizing a backwards drag; `rectsOverlap` true for a
    partial overlap; `rectsOverlap` false for two disjoint rectangles;
    `rectsOverlap` false for rectangles that only touch edges;
    `rectsOverlap` true for full containment either way round.

13. Add tests for `clampGroupDelta` to `pinboard/0.1.0/test/drag.test.mjs`
    (import it alongside the existing imports at line 9): an in-bounds delta
    passing through untouched; a leftward delta narrowed by the LEFTMOST
    member so that member lands exactly at x=0 and the others keep their
    offsets from it; an upward delta narrowed the same way at y=0; and a
    large downward delta passing through unnarrowed, because the board grows
    downward.

## Non-goals

- Do NOT add shift-click or ctrl-click toggling of individual cards into the
  selection. Marquee plus "click clears" is the whole gesture here.
- Do NOT add keyboard handling — no Escape to clear, no ctrl-A to select all,
  no arrow-key nudging.
- Do NOT persist the selection to `localStorage`, and do not change
  `src/store.js` or the stored entry shape at all.
- Do NOT add any group operation other than dragging: no group collapse, no
  group delete, no alignment or distribution commands.
- Do NOT auto-scroll the page when a marquee or a group drag reaches the
  window's edge.
- Do NOT add a Playwright suite to `pinboard/0.1.0/test/browser/board.mjs`.
  The real-engine gesture tests for this are worth having, but they are a
  separate change and that file is 404 lines of carefully hit-tested press
  points that a partial edit will break.
- Do NOT change the drag threshold, the click suppressor, or the rule that
  presses on `a, button, input` inside a summary row are left alone.

## VERIFY

1. `cd pinboard/0.1.0 && just test-js` — every test passes, including the new
   `test/select.test.mjs` and the new `clampGroupDelta` tests.
2. `cd pinboard/0.1.0 && just check` — `just build` bundles cleanly (vite
   resolves the `drag.js`/`select.js` import cycle), the demo compiles under
   `rheo compile demo/rheo`, and `demo/rheo/check.sh` passes.
3. `rg -n "select.js" pinboard/0.1.0/typst.toml` shows `src/select.js` listed
   before `src/drag.js` in the source-mode script array.
4. `rg -c "data-selected" pinboard/0.1.0/src/select.js pinboard/0.1.0/src/pinboard.css`
   shows both the module and the stylesheet using the attribute — the
   selection is visible to the reader, not just to the code.
5. `bd status <this bird's id>` reports `retired` after the flight alights.