// The one board: lays every note (or an explicit subset) out as a card the
// author can arrange by hand. Follows Pattern B from this repo's own
// CLAUDE.md — a board needs no CURRENT FILE handle, only the whole corpus
// `ideas()` already hands back with or without rheo — so this takes no
// `ctx:` parameter, asserts nothing, and panics at nothing.
#import "@rookery/core:0.1.0": ideas

// `id:` names THIS board, becoming `data-pinboard="<id>"` on the container —
// the storage key a saved layout keys on once dragging and pin-by-id land.
// `notes:` is an explicit array of `ideas()` rows to show instead of the
// whole corpus; `none` (the default) shows every note. A caller wanting less
// calls `ideas(tags: ..)` itself and hands the result in, rather than this
// package growing a query language of its own.
//
// `ideas()` reads `_registry.final()` and must run inside `#context`, so the
// whole body is one.
#let pinboard(id: "default", notes: none) = context {
  let rows = if notes != none { notes } else { ideas() }
  html.elem("div", attrs: (class: "pinboard", "data-pinboard": id), {
    for row in rows {
      html.elem(
        "article",
        attrs: (class: "pinboard-card", "data-pinboard-id": row.id),
        {
          // No page is minted under plain `typst compile` with no rheo, so
          // `row.href` is `none` there — render the title as plain content
          // rather than passing `none` to `link()`.
          let heading = if row.href != none { link(row.href, row.title) } else { row.title }
          html.elem("header", attrs: (class: "pinboard-card-handle"), heading)
          html.elem("div", attrs: (class: "pinboard-card-body"), [#row.body])
        },
      )
    }
  })
}
