---
id: rk-export-a-pinboard-as-a-tldraw-file-c564cca2
short-id: c5
title: Export a pinboard as a tldraw file
priority: 1
labels:
- feat-pinboard
- parked
deps:
- blocked-by:rk-pin-a-card-s-place-to-its-idea-id-836da185
closed: false
---
A pinboard's arrangement lives in one reader's browser, under one `localStorage` key.
That is the right default — it costs nothing, needs no server, and survives the watch
server's reload — but it means an arrangement cannot be committed, shared, handed to
a co-author, or opened in anything else.

This bird gives it a door out: a button that serializes the board to a tldraw `.tldr`
file and downloads it, so an arrangement can be opened at https://www.tldraw.com/ and
kept as an artefact.

**This is deliberately parked.** It is not wanted from the outset; it is filed so the
reasoning and the format research are not lost and so the shape of the board is never
accidentally made un-serializable. Unpark it with `bd idea unpark` when it is actually
wanted.

## What it depends on

Bird `rk-pin-a-card-s-place-to-its-idea-id-836da185`, and through it the three before it. What you need from all four:

- The package is at `/home/lox/code/_fcl/rookery/pinboard/0.1.0/`.
- The board is `<div class="pinboard" data-pinboard="<board id>">`, holding one
  `<article class="pinboard-card" data-pinboard-id="<idea id>">` per note, each with a
  `<header class="pinboard-card-handle">` carrying the note's title as a link, and a
  `<div class="pinboard-card-body">`.
- `src/drag.js` exports `readPosition(card)` → `{x, y}`. `src/collapse.js` exports
  `isCollapsed(card)`.
- `src/store.js` holds the layout under `rookery-pinboard:<board id>` as an object from
  idea id to `{x, y, collapsed}`.
- `src/pinboard.js` is the boot module and vite's entry.
- `typst.toml`'s `[tool.rheo.source.html]` `js_scripts` array lists the unbundled ES
  modules dependency-first; rheo copies exactly that list rather than scanning imports.
- `src/board.typ` emits the board from `@rookery/core`'s `ideas()` rows, whose fields
  include `id`, `title` and `text` — `text` being the note's prose flattened to a
  plain string.

Touches: pinboard/0.1.0/src/tldraw.js, pinboard/0.1.0/src/board.typ, pinboard/0.1.0/src/pinboard.js, pinboard/0.1.0/src/pinboard.css, pinboard/0.1.0/typst.toml, pinboard/0.1.0/test/tldraw.test.mjs, pinboard/0.1.0/readme.md

## The format, researched before this bird was written

A `.tldr` file is plain JSON with exactly three top-level keys — the shape is defined
by tldraw's own validator in `packages/tldraw/src/lib/utils/tldr/file.ts`:

```json
{
  "tldrawFileFormatVersion": 1,
  "schema": { "schemaVersion": 2, "sequences": { "com.tldraw.store": 4, "...": 0 } },
  "records": [ { "id": "...", "typeName": "..." } ]
}
```

- `records` is a FLAT ARRAY, not a map. Every record has an `id` and a `typeName`.
- The base records are required and a file without them opens blank:
  `document:document`, `page:page`, and `camera:page:page`.
- `schema.sequences` is a map of namespaced migration-sequence ids
  (`com.tldraw.store`, `com.tldraw.shape`, `com.tldraw.shape.geo`,
  `com.tldraw.shape.text`, `com.tldraw.page`, `com.tldraw.camera`,
  `com.tldraw.document`, `com.tldraw.instance`, and so on) to integers. `schemaVersion`
  is 2 for any modern tldraw; `schemaVersion: 1` is the legacy shape and is not what to
  write.
- A shape record carries `typeName: "shape"`, a `type` (`"note"`, `"geo"`, `"text"`),
  `x`, `y`, `parentId: "page:page"`, and a `props` object.
- **Text goes in `props.richText`, in ProseMirror's shape — not `props.text`**, which
  is the deprecated field and is one of the named causes of a file loading to a blank
  canvas.

**The sharp edge, and the reason step 1 exists: a malformed `.tldr` fails SILENTLY.**
tldraw opens it to an empty canvas with no error reported anywhere. A wrong sequence
number, a missing base record or a legacy property name all produce the same nothing.
So this cannot be written speculatively and declared done.

## Steps

1. **Establish the ground truth before writing the emitter.** Open
   https://www.tldraw.com/, place two or three sticky notes, export the document as a
   `.tldr` file, and read it. Take the `schema.sequences` map and the exact `props`
   shape of a note shape from THAT file rather than from this description or from
   memory. The numbers in `sequences` move with tldraw releases, and a stale set is
   exactly the silent failure above.

   Record the tldraw version the fixture came from in a comment at the top of
   `src/tldraw.js`, as a present-tense fact about which release the emitted shape
   matches. If a `.tldr` cannot be obtained, STOP and say so rather than guessing the
   sequence numbers — that is the one part of this bird that cannot be derived.

2. **Write `src/tldraw.js`**, exporting one pure function:

   ```js
   export function boardToTldraw(cards, opts)
   ```

   `cards` is an array of `{ id, title, text, x, y, collapsed }` — plain data, no DOM.
   It returns the file object. Keeping it pure of the DOM is what makes step 5's test
   possible at all, given that a real `.tldr` comparison is the only meaningful
   assertion available.

3. **Map one card to one tldraw note shape.** Use `type: "note"` — a sticky note is
   what a card on a corkboard is, and it carries its own text without a second `text`
   shape bound to it. The shape's `x`/`y` come straight from the card's `--pin-x` and
   `--pin-y`: both coordinate systems are pixels with the origin at the top left and
   y increasing downward, so no transform is needed.

   Build the shape id as `shape:` plus a slug of the note's own idea id, so two exports
   of the same board produce the same ids and a diff between them shows only what
   actually moved. Sanitize the slug to what tldraw accepts as an id — strip anything
   outside `[A-Za-z0-9_-]`.

4. **Put the note's title and prose in `props.richText`** as a ProseMirror document —
   a `doc` with `paragraph` nodes of `text` — copying the exact shape out of the
   fixture from step 1. A collapsed card exports its title only; an expanded card
   exports its title followed by its prose. That keeps the exported file a picture of
   what the author was actually looking at.

5. **Add the export button.** Emit it from `src/board.typ` as a sibling of the cards,
   inside the board container:
   `<button class="pinboard-export" type="button">Export</button>`. Wire it in
   `src/pinboard.js`: on click, read every card's id, title, text, position and
   collapsed state from the DOM, call `boardToTldraw`, and download the result as a
   `Blob` of `application/json` via an object URL and a synthetic `<a download>` click,
   naming the file `<board id>.tldr`. Revoke the object URL afterwards.

   Style `.pinboard-export` in `src/pinboard.css` as a small control pinned to a
   corner of the board, scoped under `.pinboard` like every other rule in that file.

6. **Add `"src/tldraw.js"` to `[tool.rheo.source.html]`'s `js_scripts` array in
   `typst.toml`,** before `"src/pinboard.js"`. The array is dependency-first.

7. **Write `test/tldraw.test.mjs`.** Assert the envelope — `tldrawFileFormatVersion`
   is 1, `schema.schemaVersion` is 2, `records` is an array, and the three base
   records `document:document`, `page:page` and `camera:page:page` are all present.
   Assert one card becomes one shape record with the right `x`/`y` and a
   `props.richText` containing the title. Assert `props.text` is absent. Assert the
   same input twice yields identical shape ids.

8. **Round-trip it by hand, and say in the bird's flight that you did.** Export the
   demo board, open the file at https://www.tldraw.com/, and confirm the notes appear
   at the arrangement they were exported from. The unit test above cannot catch a
   wrong sequence number; only this can.

9. **Document it in `readme.md`**: what the button does, that the file opens at
   tldraw.com, that it is an export and not a sync, and that editing the file and
   bringing it back is not supported.

## Non-goals

- **No import.** Reading a `.tldr` back into a pinboard is not this bird. Positions
  come from `src/store.js` and nowhere else.
- **No tldraw dependency.** Do not add `tldraw` or `@tldraw/*` to `package.json`. The
  file is JSON and this package writes it directly; pulling in the SDK to write a
  static object would be an enormous dependency for a serializer.
- **No embedded tldraw canvas.** The pinboard is not becoming a tldraw editor.
- **No other export format** — no SVG, no PNG, no JSON of its own, no Excalidraw.
- **No arrows, no connectors, no frames, no groups.** Notes and their positions.
- **No change to `src/store.js`** and no change to what is stored.
- **Do not guess the `schema.sequences` numbers.** See step 1.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/pinboard/0.1.0`:

1. `just build` succeeds.
2. `just test-js` passes, including the new `test/tldraw.test.mjs`.
3. `just check` succeeds, and `rg -c 'pinboard-export' demo/rheo/build/index.html`
   reports 1.
4. `rg -n 'props.text' src/tldraw.js` returns nothing, and `rg -n 'richText'
   src/tldraw.js` finds the ProseMirror shape.
5. `rg -n 'src/tldraw.js' typst.toml` shows it listed before `src/pinboard.js`.
6. The manual round trip in step 8 succeeded: a file exported from the demo board
   opens at tldraw.com showing the notes in the arrangement they were exported from,
   not a blank canvas.