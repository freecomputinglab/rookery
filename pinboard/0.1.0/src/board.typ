// The one board: lays every note (or an explicit subset) out as a card the
// author can arrange by hand. Follows Pattern B from this repo's own
// CLAUDE.md — a board needs no CURRENT FILE handle, only the whole corpus
// `ideas()` already hands back with or without rheo — so this takes no
// `ctx:` parameter, asserts nothing, and panics at nothing.
//
// A CARD IS A `#window`, not a shape of this package's own. Core already
// draws a note as a left rule with the note's id on a hat across the top and
// a `<details>` under it that opens on a click, so a card that reuses it
// inherits the frame, the disclosure (which needs no JavaScript at all), and
// every theme property a project sets through `#show: rookery.with(pad:,
// rule-width:, border-color:, ..)` — core emits those onto the window itself.
// This package draws only the shell that puts the window somewhere on the
// board.
#import "@rookery/core:0.1.0": ideas, window

// `id:` names THIS board, becoming `data-pinboard="<id>"` on the container —
// the storage key a saved layout keys on. `notes:` is an explicit array of
// `ideas()` rows to show instead of the whole corpus; `none` (the default)
// shows every note. A caller wanting less calls `ideas(tags: ..)` itself and
// hands the result in, rather than this package growing a query language of
// its own. `folded:` is the INITIAL state of a card the reader has never
// touched — `true` for a board of titles alone, McPhee-fashion; a card whose
// state is in the store is restored to that instead (`src/pinboard.js`).
//
// `ideas()` reads `_registry.final()` and must run inside `#context`, so the
// whole body is one.
#let pinboard(id: "default", notes: none, folded: false) = context {
  let rows = if notes != none { notes } else { ideas() }
  html.elem("div", attrs: (class: "pinboard", "data-pinboard": id), {
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
  })
}
