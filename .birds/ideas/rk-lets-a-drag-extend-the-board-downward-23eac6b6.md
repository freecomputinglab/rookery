---
id: rk-lets-a-drag-extend-the-board-downward-23eac6b6
short-id: '23'
title: Lets a drag extend the board downward
priority: 3
labels:
- feat-pinboard-drag-extends-board
deps: []
closed: false
---
Dragging a card down currently stops at the board's present bottom edge, so a
board can never be made taller by hand. `pointermove` in
`pinboard/0.1.0/src/drag.js:145-149` clamps the card against
`{ width: board.scrollWidth, height: board.scrollHeight }`, and the board's
height comes from `--pinboard-height`, which `sizeBoard` in
`pinboard/0.1.0/src/pinboard.js:30-38` computes as the tallest card's bottom
plus 24px. The two together are a floor the reader cannot push past: the board
is only ever as tall as the cards already in it, and a card can only ever go
where the board already reaches. Since `sizeBoard` recomputes from every card
on each change it also SHRINKS the board when cards move up, which is the
other half of the report — the space contracts and then there is no way to
grow it again.

The fix is to stop clamping the vertical axis at all and let the board's
height follow the drag. The horizontal axis stays clamped: the board is as
wide as the page column and growing it sideways would add a horizontal
scrollbar to the whole page, which is not wanted.

Touches: pinboard/0.1.0/src/drag.js, pinboard/0.1.0/src/pinboard.js, pinboard/0.1.0/test/drag.test.mjs

## Steps

1. In `pinboard/0.1.0/src/drag.js`, change `clampPosition` (lines 70-80) so it
   clamps only `x` against the board and floors `y` at zero with no upper
   bound:

   ```js
   // Clamps a card's position to the board's own coordinate space. `x` is
   // held inside the board's width — the board is as wide as the page column
   // and a card past its right edge would give the whole page a horizontal
   // scrollbar. `y` has a floor and NO ceiling: a drag downward is how a
   // reader makes the board taller, and `src/pinboard.js`'s `sizeBoard`
   // grows `--pinboard-height` to whatever the drag reaches. Hence
   // `boardSize.height` is not read here.
   export function clampPosition(pos, size, boardSize) {
     const maxX = Math.max(0, boardSize.width - size.width);
     return {
       x: Math.min(Math.max(0, pos.x), maxX),
       y: Math.max(0, pos.y),
     };
   }
   ```

   Leave the third parameter taking an object with `width` and `height` as it
   is — the call site passes both and the shape is fine; only `width` is read.

2. Still in `src/drag.js`, give `makeDraggable` a second optional callback so
   the host can re-measure the board while the drag is in flight. Immediately
   after the `writePosition(card, clamped.x, clamped.y)` call at line 150, add:

   ```js
   opts.onMove?.(card);
   ```

3. Extend the module header comment at `src/drag.js:25-29` (the paragraph
   about `opts.onChange`) with one sentence saying that `opts.onMove`, unlike
   `onChange`, IS called on every `pointermove` of a real drag, and exists so
   the board's height can follow a card dragged past its bottom edge; it must
   therefore stay cheap and must not write to storage.

4. In `pinboard/0.1.0/src/pinboard.js`, add a helper next to `sizeBoard`
   (which starts at line 30) that raises the board's height for ONE card
   without measuring every card — this is the per-frame path and `sizeBoard`'s
   loop over a hundred cards forces a layout for each:

   ```js
   // The per-frame half of `sizeBoard`, for a card being dragged: raises
   // `--pinboard-height` to clear this one card's bottom edge and never
   // lowers it, so a drag downward grows the board under the pointer
   // instead of stopping at its old extent. The drag's end calls `persist`,
   // and so `sizeBoard`, which recomputes the exact height from every card.
   function growBoardFor(board, card) {
     const bottom = readPosition(card).y + card.getBoundingClientRect().height + 24;
     const current = parseFloat(board.style.getPropertyValue("--pinboard-height")) || 0;
     if (bottom > current) board.style.setProperty("--pinboard-height", `${bottom}px`);
   }
   ```

5. Wire it: change the `makeDraggable` call at `src/pinboard.js:113` to

   ```js
   makeDraggable(board, { onChange: persist, onMove: (card) => growBoardFor(board, card) });
   ```

6. Fix the comment at `src/pinboard.js:26-29`. It currently claims the board's
   height "only ever grows to fit its tallest column of cards — nothing here
   shrinks it", which is not true of `sizeBoard` (it recomputes from every
   card, so it shrinks too) and is the behaviour this change depends on.
   Replace that clause with a present-tense statement that `sizeBoard`
   recomputes the exact height from every card on every change, so the board
   both grows and shrinks with its content, while `growBoardFor` is the
   grow-only path used during a drag.

7. Update the two unit tests in `pinboard/0.1.0/test/drag.test.mjs` that
   assert the old vertical ceiling:

   - `"clampPosition keeps the card's far edge inside the board"` (lines
     55-62) currently expects `{ x: 900, y: 600 }` from a position of
     `{ x: 1150, y: 750 }`. The x expectation still holds; y is now
     unclamped, so the expectation becomes `{ x: 900, y: 750 }`. Rename the
     test to `"clampPosition keeps the card's right edge inside the board and leaves y alone"`.
   - `"clampPosition never asks for a negative max when the card is larger than the board"`
     (lines 64-71) passes `{ x: 500, y: 500 }` with a card larger than the
     board and expects `{ x: 0, y: 0 }`. x is still floored to 0; y now stays
     500, so the expectation becomes `{ x: 0, y: 500 }`.

8. Add one new test in the same file asserting the new rule directly:

   ```js
   test("clampPosition lets a card pass the board's bottom edge, growing it", () => {
     const pos = clampPosition(
       { x: 40, y: 5000 },
       { width: 300, height: 200 },
       { width: 1200, height: 800 },
     );
     assert.deepEqual(pos, { x: 40, y: 5000 });
   });
   ```

## Non-goals

- Do NOT let the board grow horizontally, and do not add any horizontal
  scrolling. The right-edge clamp stays exactly as it is.
- Do NOT add auto-scrolling of the page while the pointer nears the window's
  bottom edge during a drag. Useful, but a separate change with its own
  timing behaviour to get right.
- Do NOT change `src/store.js` or the persisted entry shape. Positions are
  already stored as plain numbers with no bound.
- Do NOT touch the 480px floor in `pinboard/0.1.0/src/pinboard.css:22`
  (`min-height: max(480px, var(--pinboard-height, 0px))`) — an empty board
  still wants a minimum size, and `max()` already lets `--pinboard-height`
  win whenever it is larger.
- Do NOT add a selection or group-drag behaviour here. That is bird
  `rk-marquee-selects-cards-and-drags-them-as-8e861d89` and it edits the same
  `pointermove` block, which is why it waits on this one.

## VERIFY

1. `cd pinboard/0.1.0 && just test-js` — all tests pass, including the new
   `clampPosition` test from step 8.
2. `cd pinboard/0.1.0 && just check` — the demo builds and
   `demo/rheo/check.sh` passes.
3. `rg -n "boardSize.height" pinboard/0.1.0/src/drag.js` prints nothing: the
   vertical ceiling is genuinely gone, not merely raised.
4. `rg -n "onMove" pinboard/0.1.0/src/drag.js pinboard/0.1.0/src/pinboard.js`
   shows the callback both invoked in `drag.js` and supplied in `pinboard.js`.
5. `bd status <this bird's id>` reports `retired` after the flight alights.