// The one board: lays every note (or an explicit subset) out as a card the
// author can arrange by hand. Follows Pattern B from this repo's own
// CLAUDE.md — a board needs no CURRENT FILE handle, only the whole corpus
// `ideas()` already hands back with or without rheo — so this takes no
// `ctx:` parameter and panics at nothing. It does assert on `layout:`, which
// is this package's own value, not rheo's.
//
// A CARD IS A `#window`, not a shape of this package's own. Core already
// draws a note as a left rule with the note's id on a hat across the top and
// a `<details>` under it that opens on a click, so a card that reuses it
// inherits the frame, the disclosure (which needs no JavaScript at all), and
// every theme property a project sets through `#show: rookery.with(pad:,
// rule-width:, border-color:, ..)` — core emits those onto the window itself.
// This package draws only the shell that puts the window somewhere on the
// board.
#import "@rookery/core:0.1.1": ideas, window

// `id:` names THIS board, becoming `data-pinboard="<id>"` on the container —
// the storage key a saved layout keys on. `notes:` is an explicit array of
// `ideas()` rows to show instead of the whole corpus; `none` (the default)
// shows every note. A caller wanting less calls `ideas(tagged: ..)` itself and
// hands the result in, rather than this package growing a query language of
// its own. `folded:` is the INITIAL state of a card the reader has never
// touched, and defaults to `true`: a board of titles alone is the McPhee
// arrangement, and the one a reader takes in whole. `false` opens every card's
// body instead. A card whose state is in the store is restored to that rather
// than to this (`src/pinboard.js`). `layout:` is the INITIAL arrangement for a
// card the store has nothing for, `"stack"` (the default) or `"flow"` —
// emitted as `data-pinboard-layout="<value>"` on the container. `"stack"`
// places every unplaced card in one column, top to bottom, in the order
// `ideas()` (or `notes:`) hands them back — the sequence a reader already
// reads every other rookery view in. `"flow"` is the older wrapping grid.
// Either way this only ever places a card the store has nothing for; one the
// reader has already dragged never moves.
//
// `ideas()` reads `_registry.final()` and must run inside `#context`, so the
// whole body is one.
#let pinboard(id: "default", notes: none, folded: true, layout: "stack") = context {
  assert(
    layout == "stack" or layout == "flow",
    message: "@rookery/pinboard: `layout:` must be \"stack\" or \"flow\", got " + repr(layout),
  )
  let rows = if notes != none { notes } else { ideas() }
  html.elem(
    "div",
    attrs: (class: "pinboard", "data-pinboard": id, "data-pinboard-layout": layout),
    {
      for row in rows {
        html.elem(
          "article",
          attrs: (class: "pinboard-card", "data-pinboard-id": row.id),
          // `backlink: false`: a board RENDERS the whole corpus rather than
          // pointing at any of it, so a card must not put the page carrying the
          // board into every note's Backlinks.
          window(row.id, folded: folded, backlink: false),
        )
      }
    },
  )
}
