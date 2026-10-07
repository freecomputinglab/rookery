// The record at the top of a todo note: one row naming the todos still in front
// of it.
//
// Same two-column shape and gutter as @rookery/meetings' `with:` record and
// @rookery/bibtex's citation block, with this package's own classes — a project
// reading a todo must not have to install either of those to see this block.
//
// HTML only: `html.elem` contributes nothing at all on a paged target, element
// and children alike. That is the same trade every view here makes.
#import "graph.typ": *

// `deps` is an array of already-normalized handles. Blockedness is NOT derived
// here: `blockers-of` is the one place that decides which of a todo's deps are
// still in its way, and a one-key row is what lets this call it rather than
// restate it — it reads `row.deps` and nothing else.
#let todo-blocked-by(deps) = if deps.len() > 0 {
  context {
    let graph = todo-graph()
    let open = blockers-of((deps: deps), graph)
    if open.len() > 0 {
      html.elem("dl", attrs: (class: "todo-fields"), {
        html.elem("dt", "Blocked by")
        // Comma-joined rather than one per line: a handle carries no commas of
        // its own, so a row of them reads as a list without needing a column.
        html.elem(
          "dd",
          open
            .map(d => {
              let row = graph.nodes.at(d)
              let label = _label(row)
              // `href` is `none` where nothing mints pages, so a blocker
              // degrades to unlinked text rather than a dead anchor.
              if row.href == none {
                html.elem("span", label)
              } else {
                html.elem("a", attrs: (href: row.href), label)
              }
            })
            .join(", "),
        )
      })
    }
  }
}
