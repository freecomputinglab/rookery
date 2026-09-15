---
id: rk-reopen-a-card-whose-stored-entry-says-781adaa5
short-id: 781a
title: Reopen a card whose stored entry says it's open
priority: 2
labels:
- fix-pinboard-restore
deps: []
closed: false
---
Touches: pinboard/0.1.0/src/pinboard.js, pinboard/0.1.0/test/browser/board.mjs

## What's wrong

`pinboard/0.1.0/src/pinboard.js`'s `layOutBoard` restores a card's persisted
disclosure state from `src/store.js` on every rebuild (page load, or a
board rebuilt after content changes). The restore loop, at line 76, is:

```js
if (entry.collapsed) setCollapsed(card, true);
```

This only ever re-*closes* a card. If a card was OPEN when its position and
collapsed state were last saved (`entry.collapsed === false`), nothing here
puts it back into the open state on the next rebuild — the board's default
markup, per `board.typ`'s `folded: true` default, starts every card closed
(no `open` attribute on `<details data-rookery="window-details">`), and this
loop never overrides that default when the stored entry says "should be
open". A card's dragged position restores correctly (`writePosition` above
it, unconditional); only the disclosure state is lost, silently, with no
error.

## Fix

At `pinboard/0.1.0/src/pinboard.js:76`, replace the one-sided restore with a
call that sets BOTH states explicitly, using the existing `setCollapsed(card,
collapsed)` from `pinboard/0.1.0/src/collapse.js` (already imported in this
file — check the top of `pinboard.js` for its import line and keep the same
import style):

```js
setCollapsed(card, entry.collapsed);
```

`setCollapsed`'s second parameter is already a plain boolean (see
`pinboard/0.1.0/src/collapse.js:27`, `export function setCollapsed(card,
collapsed)`), so this is a direct swap — no new import needed if
`setCollapsed` is already imported for use elsewhere in `pinboard.js`; if it
is only `isCollapsed` currently imported, add `setCollapsed` to that same
import line.

## Do NOT

- Do not change `board.typ`'s `folded:` default or any Typst source — this
  is a pure JS bug in how a stored entry's `collapsed: false` is applied.
- Do not touch `persist()` (lines 52-60) — it already reads the card's live
  state correctly via `isCollapsed(card)`; the bug is only in the restore
  direction.
- Do not add a third disclosure state or a migration for old stored entries
  — `entry.collapsed` is always a boolean already (see `persist`'s own
  write), so the fix is a one-line change, not a data-shape change.

## Add a regression test

`pinboard/0.1.0/test/browser/board.mjs` already has a browser suite for this
package (added by an earlier landing). That suite's persistence/reload case
was deliberately written to only exercise the closed round trip, exactly
because of this bug — its own comment says as much. Add a case there that:

1. Opens a card (click its `[data-rookery="window-title"]` summary, or
   however the existing suite already toggles a card's `<details>` — follow
   that suite's existing pattern rather than inventing a new one).
2. Reloads the page (same navigation the existing reload case in that file
   already uses).
3. Asserts the card's `[data-rookery="window-details"]` element has the
   `open` attribute after reload.

Read the existing test file first to match its structure (imports, the
shared harness at `test/browser/harness.mjs`, how it locates the built demo)
rather than writing a new file.

## VERIFY

1. `cd pinboard/0.1.0 && just check` — must still print `demo/rheo OK`.
2. `cd pinboard/0.1.0 && node --test test/*.test.mjs` — the 32 existing
   node-test assertions must still pass (this bug lives only in DOM-driven
   restore, which the node suite does not exercise).
3. `cd pinboard/0.1.0 && node test/browser/board.mjs` — must print
   `ok pinboard-board` for at least one engine (webkit/chromium/firefox),
   including your new open-then-reload case.
4. Confirm the bug is real before your fix and gone after: temporarily
   revert your one-line change, re-run `node test/browser/board.mjs`, and
   confirm your new case fails. Re-apply your fix and confirm it passes
   again.
5. `bd status <this-bird's-id>` — must read `in_flight` until you alight,
   then `retired` after.