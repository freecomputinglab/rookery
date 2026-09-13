# @rookery/pinboard

A board of draggable cards for arranging [`@rookery/core`](../../core/0.1.0)
notes by hand. The motivating use is John McPhee's structural method: write
each component of a piece on its own card, put the cards where you can see
them all at once, and move them around until a sequence appears. A card is
reduced to its title on the board — you arrange labels, not prose — while its
body goes on changing underneath, wherever the note itself is edited.

```typst
#import "@rookery/core:0.1.0": idea
#import "@rookery/pinboard:0.1.0": pinboard

#idea("outline", title: [Outline])[...]
#idea("interview", title: [The interview])[...]

#pinboard()
```

## `#pinboard(id:, notes:)`

- **`id:`** names THIS board. It becomes `data-pinboard="<id>"` on the
  container, and is the whole of the storage key
  (`rookery-pinboard:<id>`) a saved layout keys on. A project running two
  boards gives them two ids; renaming a board's id starts a fresh layout
  under a new key. Defaults to `"default"`.
- **`notes:`** an explicit array of [`ideas()`](../../core/0.1.0) rows to show
  instead of the whole corpus. `none` (the default) shows every note. This is
  how a caller narrows the board without this package growing a query
  language of its own: `ideas(tags: "..")` already narrows, and the result is
  handed straight in.

## Import both packages

A project using `#pinboard` imports **both** `@rookery/core` (for `idea` and
whatever else it authors notes with) and `@rookery/pinboard`, in its own
`.typ` files — the same requirement every other JS-shipping `@rookery`
package states, because rheo's package-asset detection scans a project's own
imports, never a package's internal ones.

## What this release is

A board of cards, each draggable by its handle and collapsible to its title,
whose arrangement is pinned to the note underneath it rather than to the
page, the file, or the build. A card's place is keyed on `core`'s own stable
per-note id, so it survives edits to the note's title and prose, and moves
with the note between files. The layout lives in the reader's own browser,
under `localStorage` at `rookery-pinboard:<board id>` — per-browser, not
shared between readers and not committed to the project. Under `rheo watch`,
a save reloads the whole page (rheo has no lighter refresh hook), and the
board comes back exactly as it was left, because every card's position is
re-read from that store on boot rather than recomputed.

A note with no stored entry — one written since the board was last
arranged — falls back to a flow layout: laid out left to right and wrapping
into rows, in the first free slot of the grid.

## Requirements

- `@rookery/core` 0.1.0. A hard import.
- rheo 0.6.2 or later.
- A built package: `dist/` must exist before a project sees an edit.

## Development

```sh
cd pinboard/0.1.0
just build      # bundles src/ into dist/
just test-js    # the flow layout tests
just check      # builds, then compiles and asserts on the demo
```
