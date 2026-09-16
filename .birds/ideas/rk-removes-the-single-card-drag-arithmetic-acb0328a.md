---
id: rk-removes-the-single-card-drag-arithmetic-acb0328a
short-id: acb
title: Removes the single-card drag arithmetic nothing calls
priority: 2
labels:
- chore-pinboard-drop-single-card-clamp
deps:
- blocked-by:rk-clamps-a-group-drag-against-every-card-d9c278df
closed: false
---
`offsetPosition` and `clampPosition` in `pinboard/0.1.0/src/drag.js` have no
caller left. The drag path computes one delta for the whole selection through
`clampGroupDelta` and writes each card from it, so neither function runs in the
package any more — only in its own unit tests. Both go, and their tests with
them.

Touches: pinboard/0.1.0/src/drag.js, pinboard/0.1.0/test/drag.test.mjs

## Why they are unreachable, and why nothing outside cares

`makeDraggable`'s `pointermove` handler builds an `items` array from the dragged
cards, calls `clampGroupDelta(items, delta, board.scrollWidth)` once, and then
writes each card as `starts[i] + delta`. No single-card position is computed and
no single-card clamp is applied, so neither of these two functions is on that
path.

They are `export`ed, but that does not make them anyone's API:

- Inside the package, `src/pinboard.js` imports only `makeDraggable`,
  `readPosition` and `writePosition` from this module, and `src/select.js`
  imports only `readPosition` and `movedEnough`. VERIFIED: nothing else in
  `src/` names either function.
- Outside the package, a consumer never imports these functions individually. A
  released build loads `dist/lib.js`, and a git-ref build loads the modules
  listed in `typst.toml`'s `[tool.rheo.source.html]` `js_scripts` as plain
  scripts. Neither shape exposes named imports to a consuming project.

So the removal is internal, and the only references to fix are in this package's
own test file.

## A cross-reference that has to move

`clampGroupDelta`'s comment currently explains its floor-only `dy` by pointing
at `clampPosition` — the sentence "the board's height follows a downward drag
(see `clampPosition`)" or whatever wording that comment carries when you arrive.
With `clampPosition` gone, that reference dangles. Replace it with the rule
stated directly: `dy` has a floor and no ceiling because a drag downward is how
the board is made taller, and `src/pinboard.js`'s `growBoardFor` raises
`--pinboard-height` to follow it.

**Locate every target by its symbol, not by the line numbers below.** A bird
that edits `clampGroupDelta` lands before this one and will have shifted them.

## Steps

1. In `pinboard/0.1.0/src/drag.js`, delete `offsetPosition` together with its
   comment — the comment begins "The dragged position is the drag's start
   position plus the pointer's delta" (around line 67) and the function body
   ends at the closing brace around line 78.

2. In the same file, delete `clampPosition` together with its comment — the
   comment begins "Clamps a card's position to the board's own coordinate
   space" (around line 80) and the function body ends at the closing brace
   around line 96.

3. In the same file, fix `clampGroupDelta`'s comment so it no longer refers to
   `clampPosition`, as described above. Do not otherwise reword it.

4. In the same file, check the module header comment (lines 1-32) for any
   sentence naming either deleted function, and remove or reword only such a
   sentence. If the header names neither, change nothing there and say so in
   the report.

5. In `pinboard/0.1.0/test/drag.test.mjs`, remove `offsetPosition` and
   `clampPosition` from the import block (lines 9-15), leaving
   `clampGroupDelta`, `movedEnough` and `DRAG_THRESHOLD` imported.

6. In the same file, delete the seven tests that exercise the two deleted
   functions. By name, so you do not have to trust line numbers:

   - `"offsetPosition adds the pointer's delta to the start position"`
   - `"offsetPosition returns the start position when the pointer has not moved"`
   - `"clampPosition leaves an in-bounds position untouched"`
   - `"clampPosition floors negative coordinates at zero"`
   - `"clampPosition keeps the card's right edge inside the board and leaves y alone"`
   - `"clampPosition never asks for a negative max when the card is larger than the board"`
   - `"clampPosition lets a card pass the board's bottom edge, growing it"`

   Leave every `movedEnough` and `clampGroupDelta` test exactly as it is.

7. Check the test file's own header comment (lines 1-4), which describes the
   file as unit tests for "the drag arithmetic — the pure half of the drag
   code". That is still true of what remains, so change it only if it names one
   of the deleted functions specifically.

## Non-goals

- Do NOT remove `readPosition`, `writePosition`, `movedEnough`,
  `DRAG_THRESHOLD`, `clampGroupDelta` or `makeDraggable`, or any of their
  tests. They all have live callers.
- Do NOT change `clampGroupDelta`'s behaviour or its arithmetic. This bird
  touches only the sentence in its comment that names a function being
  deleted.
- Do NOT reintroduce single-card clamping anywhere, and do not "simplify"
  `makeDraggable` to use a single-card path.
- Do NOT change `typst.toml`, `src/pinboard.js`, `src/select.js` or
  `src/pinboard.css`.
- Do NOT create a new version directory; this is a change to the shipped
  `pinboard/0.1.0`.
- Do NOT add a changelog entry — the package has none.

## VERIFY

1. `rg -n 'offsetPosition|clampPosition' /home/lox/code/_fcl/rookery/pinboard/0.1.0/src /home/lox/code/_fcl/rookery/pinboard/0.1.0/test`
   returns NOTHING.
2. `cd /home/lox/code/_fcl/rookery/pinboard/0.1.0 && just test-js` — reports
   `fail 0`, and seven fewer tests than before this change.
3. `cd /home/lox/code/_fcl/rookery/pinboard/0.1.0 && just check` passes (vite
   build, `rheo compile`, and `demo/rheo/check.sh`). The vite build failing on
   an unresolved import is the thing this step is really checking.
4. `cd /home/lox/code/_fcl/rookery/pinboard/0.1.0 && node test/browser/board.mjs`
   prints `ok pinboard-board` for webkit, chromium and firefox — the real
   gesture behaviour, unchanged by this removal. This file is NOT wired into any
   `Justfile` target, so it has to be run by name.