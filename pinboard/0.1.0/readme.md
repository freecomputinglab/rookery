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
  container — the storage key a saved layout keys on once dragging and
  persistence land. A project running two boards gives them two ids.
  Defaults to `"default"`.
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

The package, and a board that renders: cards laid out left to right and
wrapping into rows, each linking to its note's own minted page. It is a
scaffold for the mechanisms chained behind it, each adding one thing to a
board that already compiles and already appears on screen:

- **No dragging.** Cards sit where the flow layout puts them.
- **No collapsing.** Every card shows its whole body.
- **No persistence of any kind.** Nothing here saves a layout, and none
  survives a reload.

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
