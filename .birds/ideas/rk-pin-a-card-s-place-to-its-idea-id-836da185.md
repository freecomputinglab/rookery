---
id: rk-pin-a-card-s-place-to-its-idea-id-836da185
short-id: '83'
title: Pin a card's place to its idea id
priority: 5
labels:
- feat-pinboard
deps:
- blocked-by:rk-collapse-a-pinboard-card-to-its-title-8f87e378
closed: false
---
This is the bird the whole package exists for. A card stays where the author put it
while the note underneath it goes on being edited — the position belongs to the IDEA,
not to the paragraph, not to the file, and not to this particular build of the site.

Without it the package is a toy: every save reshuffles the board and the arrangement
the author spent an hour finding is gone.

## Why the rheo watch server makes this urgent rather than optional

rheo's dev server was read before this bird was written, so here is what it actually
does. `crates/html/src/server.rs:129-143` serves an SSE stream at `/events`;
`server.rs:134` sends `Event::default().event("reload").data("refresh")` after a
successful rebuild; and the client script injected before `</body>`
(`server.rs:273-283`) opens an `EventSource('/events')` and, on a `reload` event,
calls **`location.reload()`**.

That is a hard, whole-page reload. rheo preserves no document state across it — not
scroll position, not focus, nothing — and it exposes NO extension point: there is no
`rheo:*` custom event, no pre-reload hook, no registry a package can put a callback
in. (The rheo checkout on this machine is at `/home/lox/code/_fcl/rheo` if you want
to confirm it; you should not need to.)

So there is no clever way for a pinboard to survive an edit. The only way is for the
board to re-derive every card's position from a store at boot, on every single load,
indistinguishably from the first one. Which means the requirement "the watch server
should refresh the pinboard automatically when content or title changes" needs no
work at all beyond this bird: rheo already reloads the page on every rebuild, and
once positions come from a store, that reload IS the live-updating pinboard.

## What this bird depends on

Bird `rk-collapse-a-pinboard-card-to-its-title-8f87e378`, and through it the two before it. Everything you need from all three:

- The package is at `/home/lox/code/_fcl/rookery/pinboard/0.1.0/`.
- `src/board.typ` emits `<div class="pinboard" data-pinboard="<board id>">` holding
  one `<article class="pinboard-card" data-pinboard-id="<idea id>">` per note. The
  `data-pinboard-id` value is `core`'s own stable per-note `id`, from the `ideas()`
  rows defined at `/home/lox/code/_fcl/rookery/core/0.1.0/src/data.typ:273` — the
  field list is at `data.typ:292` and `id` is documented as the stable identifier at
  `data.typ:294`. A note keeps that id when its title changes, when its prose
  changes, and when it moves between files, which is exactly the property this bird
  is built on.
- `src/pinboard.js` is the boot module and vite's entry: it finds every
  `[data-pinboard]`, computes a flow layout with `flowPositions` from
  `src/layout.js`, writes positions into the CSS custom properties
  `--pin-x`/`--pin-y`, then calls `makeDraggable(board)` and
  `makeCollapsible(board)`.
- `src/drag.js` exports `readPosition(card)` → `{x, y}` and `writePosition(card, x,
  y)`, the only pair that touches those custom properties.
- `src/collapse.js` exports `isCollapsed(card)` and `setCollapsed(card, collapsed)`,
  the only pair that touches the card's `data-collapsed` attribute, and
  `setCollapsed` works on a card that has never been clicked.
- `typst.toml`'s `[tool.rheo.source.html]` `js_scripts` array lists the unbundled ES
  modules dependency-first; rheo copies exactly that list rather than scanning
  imports.

This repo contains **no browser-storage code today** — `rg -n 'localStorage|
sessionStorage|indexedDB'` over the tree returns nothing. This bird introduces the
first of it, which is why the guards in step 3 are spelled out rather than assumed.

Touches: pinboard/0.1.0/src/store.js, pinboard/0.1.0/src/pinboard.js, pinboard/0.1.0/src/drag.js, pinboard/0.1.0/src/collapse.js, pinboard/0.1.0/typst.toml, pinboard/0.1.0/test/store.test.mjs, pinboard/0.1.0/readme.md

## Steps

1. **Write `src/store.js`**, exporting:

   ```js
   export function loadBoard(boardId)          // -> { "<idea id>": { x, y, collapsed } }
   export function saveCard(boardId, ideaId, entry)
   export function storageKey(boardId)         // -> `rookery-pinboard:${boardId}`
   ```

2. **Key the store on the board id alone** — `rookery-pinboard:<board id>` — and NOT
   on `location.pathname`. The board id is the `data-pinboard` attribute, which comes
   from the author's own `#pinboard(id: "..")` argument. Keying on the path instead
   would mean that moving the page that holds the board, or renaming the file, throws
   the arrangement away; keying on the author's chosen name means it survives both.
   The cost is that two boards sharing an id share a layout, which is the author's
   business and is why the argument exists.

3. **Make every storage access safe.** `localStorage` throws on access in a private
   window, when site data is blocked, and inside some embedding contexts — the getter
   itself can throw, not just the read. Wrap every read and every write in
   `try`/`catch`, and on failure fall through to the flow layout and carry on. A
   board that renders unarranged is a working board; a board that throws during boot
   renders nothing.

   Guard the parse as well: `JSON.parse` on a corrupted value throws, and a value
   that parses to a non-object, or to an entry whose `x`/`y` are not finite numbers,
   must be discarded rather than written into a card's style. Validate each entry and
   skip the bad ones individually, so one malformed entry does not cost the board its
   whole layout.

4. **Apply the store at boot, in `src/pinboard.js`, before anything is painted.** The
   ordering is the substance of this bird:

   1. Read the board's stored entries with `loadBoard(boardId)`.
   2. Partition the board's cards into those whose `data-pinboard-id` has a stored
      entry and those that do not.
   3. For a card WITH an entry: `writePosition(card, entry.x, entry.y)` and, when
      `entry.collapsed` is true, `setCollapsed(card, true)`.
   4. For a card WITHOUT an entry — a note written since the board was last arranged
      — compute a flow position with `flowPositions` and apply that. Pass only the
      unplaced cards' ids to `flowPositions`, so a new note lands in the first free
      slot of the grid rather than wherever it would have fallen in a full-board
      layout. A new note must appear somewhere visible and must not land on top of
      an existing card if that is avoidable.

   Do this synchronously in the same task as boot. A stored layout applied a frame
   late is a visible jump from the grid to the arrangement on every single reload,
   which under `rheo watch` is every single save.

5. **Persist on change, from the two places that already own the state.** At the end
   of a drag — the `pointerup`/`pointercancel` path in `src/drag.js` — call
   `saveCard`. In `src/collapse.js`'s click handler, after `setCollapsed`, call
   `saveCard`. Do not persist during `pointermove`: that is a write per frame, and
   `localStorage` is synchronous and hits disk.

   Pass the save function in rather than importing `store.js` from `drag.js` and
   `collapse.js`. Give `makeDraggable` and `makeCollapsible` an `onChange` callback
   in their existing `opts` argument, and have `src/pinboard.js` supply one that
   calls `saveCard`. Both modules stay testable without a storage stub, and the
   dependency-first order in `typst.toml` stays a straight line.

6. **Write the whole entry every time.** `saveCard` reads the board's current object,
   sets `{x, y, collapsed}` for that one idea id, and writes the object back. Do not
   keep a long-lived in-memory copy and write it at intervals — two tabs open on the
   same board would then silently overwrite one another, and the last reload would
   win the whole layout rather than the last edit winning one card.

7. **Keep entries for ids that are no longer on the board. Do not prune.** A note
   deleted, renamed or temporarily commented out should find its place again when it
   comes back, and under `rheo watch` an id can vanish from a build for one save
   because of an unrelated compile error upstream. An entry is a few dozen bytes and
   the corpus is bounded by the size of the project, so growth is not a real cost. A
   prune would trade a real failure for an imaginary one. Say this in a comment at
   the point where it would be tempting to prune.

8. **Add `"src/store.js"` to `[tool.rheo.source.html]`'s `js_scripts` array in
   `typst.toml`,** first in the list — nothing imports into it and `pinboard.js`
   imports from it. The array is dependency-first and rheo copies exactly what it
   names.

9. **Write `test/store.test.mjs`.** `localStorage` does not exist under node, so stub
   a minimal one on `globalThis` in the test — a `Map` behind `getItem`/`setItem` is
   enough, and it lets you also test the throwing case by making the stub throw.
   Assert:
   - a round trip: `saveCard` then `loadBoard` returns the entry;
   - a save for one idea id leaves another id's entry untouched;
   - `loadBoard` on a key holding `"{{{"` returns an empty object rather than
     throwing;
   - `loadBoard` on a key holding `'{"a":{"x":"nope","y":3}}'` drops that entry and
     returns an empty object;
   - `loadBoard` returns an empty object when the storage stub throws on access;
   - `storageKey("notes")` is exactly `"rookery-pinboard:notes"`.

10. **Document it in `readme.md`**: that a card's place is pinned to the note's id and
    therefore survives edits to its title and prose; that the layout lives in the
    reader's own browser under `rookery-pinboard:<board id>` and so is per-browser and
    not shared or committed; that `#pinboard(id: "..")` is what names a board's
    layout, and that renaming the id starts a fresh one; and that under `rheo watch`
    a save reloads the page and the board comes back arranged.

## Non-goals

- **No server-side persistence, no writing a file, no rheo endpoint.** rheo's dev
  server has no write route, and adding one is a change to rheo, not to this package.
  Sharing or committing an arrangement is the export bird's job, not this one's.
- **No `.tldr`, no export, no import, no serialization format.**
- **No cross-tab synchronisation.** Do not listen for the `storage` event.
- **No migration or versioning of the stored shape.** It is the first version.
- **No pruning of unknown ids**, and no "tidy" or "reset" control.
- **No change to `src/board.typ`.** The DOM carries every id this bird needs.
- **Do not add a dependency.** `JSON` and `localStorage` are the whole of it.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/pinboard/0.1.0`:

1. `just build` succeeds.
2. `just test-js` passes, including the new `test/store.test.mjs`.
3. `just check` succeeds — the demo compiles and `check.sh` exits zero.
4. `rg -n 'localStorage' src/` shows it appearing in `src/store.js` and nowhere else.
5. `rg -n 'localStorage' src/store.js` shows every occurrence inside a `try` block.
6. `rg -n 'src/store.js' typst.toml` shows it first in the `js_scripts` array.