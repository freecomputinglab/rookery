---
id: rk-stack-a-board-s-cards-top-to-bottom-by-a1a92ade
short-id: a1a
title: Stack a board's cards top to bottom by default
priority: 2
labels:
- feat-pinboard
- stack-pinboard-cards-by-default
deps: []
closed: false
---
A board's initial arrangement is a wrapping grid: `flowPositions` in
`/home/lox/code/_fcl/rookery/pinboard/0.1.0/src/layout.js` lays ids left to right and
wraps at the board's rendered width. That is the wrong default for the first thing a
reader does with a board, which is READ IT. A rookery's notes already have an order —
`ideas()` hands them back sorted by id, and a run of `#window`s down a page is how
every other view in this family presents them — so a board should open as that same
sequence, one column, top to bottom, and become a two-dimensional arrangement only
once someone drags a card out of the line.

Make the stack the default and keep the grid as `layout: "flow"`.

Touches: pinboard/0.1.0/src/layout.js, pinboard/0.1.0/src/pinboard.js,
pinboard/0.1.0/src/board.typ, pinboard/0.1.0/src/pinboard.css,
pinboard/0.1.0/test/layout.test.mjs, pinboard/0.1.0/readme.md

## What is there now

- `src/layout.js` exports one function, `flowPositions(ids, opts)`, pure and
  DOM-free with `DEFAULTS = { cardWidth: 320, cardHeight: 220, gap: 24, boardWidth: 1200 }`.
  `cardHeight` is a spacing constant, not a measurement — no card's real height is
  read anywhere in the package.
- `src/pinboard.js`'s `layOutBoard(board)` restores stored cards through
  `loadBoard`/`writePosition`, collects the cards the store has nothing for into
  `unplaced`, and gives only those a flow position from
  `board.getBoundingClientRect().width`. Keep that split exactly as it is: a card the
  reader has already placed never moves.
- `src/pinboard.css` gives `.pinboard` `position: relative; min-height: 480px` and
  every `.pinboard-card` `position: absolute; width: 300px; height: auto`. Cards are
  out of flow, so the board does not grow with them — a fixed 480px is all the height
  there is.
- `src/board.typ`'s `#pinboard(id:, notes:, folded:)` writes `class="pinboard"` and
  `data-pinboard="<id>"` on the container.
- Note the 300px in the stylesheet against the 320px in `layout.js`: the flow layout's
  `cardWidth` is a spacing parameter too, and nothing in the package measures a card.
  The stack has to, because card heights differ — a folded card is one row, an open
  one is up to 200px of scrolling body.

## Steps

1. **Add `stackPositions(ids, opts)` to `src/layout.js`**, beside `flowPositions` and
   in the same style — pure, no DOM, no measurement of its own. Signature:
   `stackPositions(ids, { heights, gap, x, startY } = {})`, where `heights` is a
   `Map` from id to that card's rendered height in pixels (missing or non-finite
   entries fall back to `DEFAULTS.cardHeight`), `gap` defaults to `DEFAULTS.gap`, and
   `x`/`startY` default to `0`. Return a `Map` from id to `{x, y}`: every card takes
   the same `x`, and each `y` is the running sum of the previous cards' heights plus
   one `gap` each, starting at `startY`. Ids keep their given order — no sort here,
   `ideas()` already sorted and `src/board.typ` renders in that order.

2. **Keep `flowPositions` exactly as it is.** It stays exported, stays tested, and
   becomes the non-default layout. Do not fold the two into one function with a mode
   flag; two small pure functions read better than one that branches.

3. **Add a `layout:` parameter to `#pinboard` in `src/board.typ`**, defaulting to
   `"stack"`, accepting `"stack"` or `"flow"`, and emitted as
   `data-pinboard-layout="<value>"` on the container `div` alongside the existing
   `class` and `data-pinboard` attributes. Assert on an unknown value with a message
   naming both accepted strings — a typo'd layout should stop the build, not silently
   pick one. Document the parameter in the function's doc comment the way `id:`,
   `notes:` and `folded:` are documented there.

4. **Choose the layout in `src/pinboard.js`'s `layOutBoard`.** Read
   `board.dataset.pinboardLayout` and treat anything other than `"flow"` as
   `"stack"`, so a board built by an older copy of the Typst half (no attribute at
   all) gets the new default. Leave the `stored`/`unplaced` split above it untouched.

5. **Measure and stack the unplaced cards.** Inside the existing
   `if (unplaced.length > 0)` branch, when the layout is the stack:
   - Build `heights` by reading `card.getBoundingClientRect().height` for each
     unplaced card. Read every height before writing any position — an interleaved
     read/write per card is a forced layout per card, and a board carries a hundred
     of them.
   - Start the stack below whatever the store already placed: `startY` is the greatest
     `entry.y + <that card's height>` over the cards restored in the loop above, or
     `0` when the store had nothing. A note written since the board was last arranged
     lands under the arrangement rather than on top of it.
   - Call `stackPositions` with that `heights` map, `startY`, and `x: 0`, then write
     each position with the existing `writePosition`. The flow branch keeps calling
     `flowPositions` with the board's rendered width, unchanged.

6. **Let the board grow to its content.** A column of absolutely positioned cards
   overflows a 480px board, which is the whole reason the grid was survivable and the
   stack is not. Add a `sizeBoard(board)` helper in `src/pinboard.js` that takes the
   greatest `readPosition(card).y + card.getBoundingClientRect().height` over every
   card and writes it, plus a little slack, to a `--pinboard-height` custom property
   on the board element. Call it once at the end of `layOutBoard` and again from
   `persist` (so a drag downward and a card opening both grow the board). In
   `src/pinboard.css`, change `.pinboard`'s `min-height: 480px` to
   `min-height: max(480px, var(--pinboard-height, 0px))` and say in the comment that
   the property is written by `src/pinboard.js`.

7. **Extend `test/layout.test.mjs`** with tests for `stackPositions` — the flow tests
   stay as they are. Cover: every card shares one `x`; `y` increases strictly in the
   given order; a card's `y` is the previous card's `y` plus the previous card's
   height plus the gap, with an explicit `heights` map; an id missing from `heights`
   falls back to the default spacing rather than collapsing onto its neighbour;
   `startY` offsets every card; and the same input yields the same output twice.

8. **Update `readme.md`** — the `#pinboard(id:, notes:, folded:)` heading gains
   `layout:` and its bullet, and the prose that describes a fresh board as a grid
   says a column instead. State that the layout only ever places cards the store has
   nothing for.

## Non-goals

- **Nothing re-places a card the reader has already moved.** No "re-stack the board"
  button, no reflow on resize, no migration of existing stored layouts.
- **No change to the storage format or its key.** `rookery-pinboard:<id>` keeps
  holding `{x, y, collapsed}` per idea id; `src/store.js` is not touched.
- **Do not touch `src/drag.js` or `src/collapse.js`.** The only new call into them is
  `readPosition` in `sizeBoard`, which is already exported.
- **Do not make the cards flow in CSS.** They stay absolutely positioned on
  `--pin-x`/`--pin-y`; a stack is an initial set of coordinates, not a layout mode of
  the stylesheet.
- **No re-stacking when a card collapses.** A card that shuts leaves the gap it was
  occupying; its place is pinned. Only the board's height is recomputed.

## VERIFY

1. From `/home/lox/code/_fcl/rookery/pinboard/0.1.0`, `just test-js` exits 0, with the
   new `stackPositions` tests and the existing `flowPositions` ones both passing.
2. `just check` in the same directory exits 0 (it builds `dist/lib.js`, compiles
   `demo/rheo` and runs `demo/rheo/check.sh`).
3. Open the demo's built `index.html` in a browser with `localStorage` cleared: the
   four cards sit in one column, in the order `index.typ` declares them
   (`outline`, `interview`, `scene-one`, `counterargument`), none overlapping, and the
   board's box extends past the last card rather than clipping it.
4. Drag a card sideways, reload, and confirm it comes back where it was dropped while
   the untouched cards stay in their column.
5. Change the demo's call to `#pinboard(layout: "flow")`, recompile, clear
   `localStorage`, and confirm the old wrapping grid is back.