---
id: rk-collapse-a-pinboard-card-to-its-title-8f87e378
short-id: 8f
title: Collapse a pinboard card to its title
priority: 4
labels:
- feat-pinboard
deps:
- blocked-by:rk-drag-a-pinboard-card-by-its-handle-1d0aa913
closed: true
---
A card on a pinboard can be reduced to its title alone, and the board is then a
field of labels rather than a wall of prose.

This is the feature that makes the package worth having rather than a novelty. John
McPhee's method for finding the structure of a long piece is to write each component
on its own card and move the cards around until a sequence appears — and what makes
that possible is that you are looking at twenty titles at once, not twenty
paragraphs. A board whose cards cannot shrink shows four notes on a screen and
defeats the exercise.

It depends on drag already working. That is bird `rk-drag-a-pinboard-card-by-its-handle-1d0aa913`, and here is everything from
it and from the scaffold bird you need, so you need not read either:

- The package is at `/home/lox/code/_fcl/rookery/pinboard/0.1.0/`.
- `src/board.typ` emits `<div class="pinboard" data-pinboard="<board id>">` holding
  one `<article class="pinboard-card" data-pinboard-id="<idea id>">` per note, each
  containing `<header class="pinboard-card-handle">` (the note's title, as a link to
  the note's own page) and `<div class="pinboard-card-body">` (its prose).
- `src/pinboard.js` is the boot module and vite's entry: it finds every
  `[data-pinboard]`, lays the cards out with `flowPositions` from `src/layout.js`,
  writes each card's place into the CSS custom properties `--pin-x`/`--pin-y`, and
  calls `makeDraggable(board)` from `src/drag.js`.
- `src/drag.js` starts a drag from `pointerdown` on `.pinboard-card-handle`, and
  already returns early when the press landed on `event.target.closest("a, button,
  input, summary")` — so a `<button>` added inside the handle by this bird will NOT
  start a drag. That guard exists; do not add a second one.
- `typst.toml`'s `[tool.rheo.source.html]` `js_scripts` array lists the unbundled ES
  modules dependency-first. rheo copies exactly this list rather than scanning
  imports, so a module missing from it is absent from a git-ref build with no error.

Touches: pinboard/0.1.0/src/collapse.js, pinboard/0.1.0/src/board.typ, pinboard/0.1.0/src/pinboard.js, pinboard/0.1.0/src/pinboard.css, pinboard/0.1.0/typst.toml, pinboard/0.1.0/test/collapse.test.mjs, pinboard/0.1.0/demo/rheo/check.sh

## Steps

1. **Emit the toggle from Typst, not from JavaScript.** In `src/board.typ`, add a
   `<button>` as the FIRST child of each card's `.pinboard-card-handle`:

   ```typ
   html.elem("button", attrs: (
     class: "pinboard-card-toggle",
     type: "button",
     "aria-expanded": "true",
   ), [−])
   ```

   Emitting it server-side rather than injecting it in `pinboard.js` means the
   control is present in the HTML a reader gets with JavaScript disabled or still
   loading, and means the demo's `check.sh` can assert on it. `type="button"` is not
   optional — a `<button>` with no type inside a form submits it.

2. **Write `src/collapse.js`**, exporting:

   ```js
   export function makeCollapsible(board, opts)
   ```

   Like `makeDraggable`, it wires ONE delegated `click` listener on the board and
   lets events bubble, rather than one listener per card.

   On click, find `event.target.closest(".pinboard-card-toggle")`; return if there is
   none. Find that button's `.pinboard-card` ancestor and toggle `data-collapsed` on
   it. Keep the button's `aria-expanded` in step — `"false"` when collapsed, `"true"`
   when not — and swap its label between `−` and `+`.

3. **Export a pair of primitives alongside it:**

   ```js
   export function isCollapsed(card)
   export function setCollapsed(card, collapsed)
   ```

   `makeCollapsible`'s click handler calls `setCollapsed`, and nothing else in the
   module writes the attribute directly. The bird chained behind this one persists
   the collapsed state and will call exactly this pair; a toggle that flips the
   attribute inline makes that bird a refactor rather than an addition. The same
   reasoning produced `readPosition`/`writePosition` in `src/drag.js`.

4. **Let the caller collapse a card without a click.** `setCollapsed(card, true)` must
   work on a card that has never been clicked, so a stored state can be applied at
   boot. It therefore must not depend on any listener having run, and must set
   `aria-expanded` and the button label itself rather than leaving them to the click
   handler.

5. **Do the hiding in CSS, keyed on the attribute.** In `src/pinboard.css`:

   ```css
   .pinboard-card[data-collapsed] .pinboard-card-body { display: none; }
   ```

   Do NOT set `style.display` from JavaScript. The attribute is the single source of
   truth for the state, which is what lets step 3's `isCollapsed` be a one-line
   attribute read and what lets a consuming project restyle a collapsed card without
   fighting an inline style.

   A collapsed card must shrink to fit its handle — give `.pinboard-card` a
   `height: auto` and make sure nothing sets a fixed height on the card itself. The
   fixed `cardHeight` used by `flowPositions` in `src/layout.js` is a LAYOUT
   PARAMETER for spacing the initial grid, not a rendered height; if a rule currently
   applies it to the element, remove it.

   Style `.pinboard-card-toggle` as a small square control at the left of the handle:
   no default button chrome, `cursor: pointer`, and a visible `:focus-visible` ring.
   Scope every new rule under `.pinboard-card`, as the rest of this stylesheet is —
   it is injected into every page of a consuming project.

6. **Call it from `src/pinboard.js`**: alongside the existing `makeDraggable(board)`,
   call `makeCollapsible(board)`.

7. **Add `"src/collapse.js"` to `[tool.rheo.source.html]`'s `js_scripts` array in
   `typst.toml`,** before `"src/pinboard.js"`. The array is dependency-first.

8. **Extend `demo/rheo/check.sh`** to assert that the built HTML contains one
   `pinboard-card-toggle` per card, so a future change that drops the server-side
   button fails the check rather than silently producing a board that cannot collapse
   without JavaScript running first.

9. **Write `test/collapse.test.mjs`.** `isCollapsed`/`setCollapsed` are attribute
   reads and writes on an element, which linkedom models faithfully — this is one of
   the few things in this package a node test genuinely covers. Assert that
   `setCollapsed(card, true)` sets `data-collapsed` and `aria-expanded="false"` on
   the button, that `setCollapsed(card, false)` removes the attribute, that
   `setCollapsed` is idempotent, and that `isCollapsed` agrees with what was set.

## Non-goals

- **No animation or transition on collapse.** A height transition on an
  `auto`-height element is a separate problem and not one this bird solves.
- **No "collapse all" / "expand all" control.**
- **No persistence.** Collapsed state is lost on reload; the next bird fixes that.
  Do not add `localStorage` here.
- **No re-flow after a collapse.** Cards do not move when one shrinks — the author
  placed them, and rearranging the board under them on a toggle would undo that.
  This is a deliberate choice, not an omission.
- **Do not change `src/drag.js`.** Its existing interactive-element guard already
  covers the new button.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/pinboard/0.1.0`:

1. `just build` succeeds.
2. `just test-js` passes, including the new `test/collapse.test.mjs`.
3. `just check` succeeds — the demo compiles and the extended `check.sh` exits zero.
4. `rg -c 'pinboard-card-toggle' demo/rheo/build/index.html` reports the same count
   as `rg -c 'data-pinboard-id' demo/rheo/build/index.html`.
5. `rg -n 'display: none' src/pinboard.css` shows the hide rule keyed on
   `[data-collapsed]`, and `rg -n 'style.display' src/collapse.js` returns nothing.
6. `rg -n 'src/collapse.js' typst.toml` shows it listed before `src/pinboard.js`.