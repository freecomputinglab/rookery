// The record at the top of a todo note: one row naming the todos still in front
// of it.
//
// Same two-column shape and gutter as @rookery/meetings' `with:` record and
// @rookery/bibtex's citation block, with this package's own classes — a project
// reading a todo must not have to install either of those to see this block.
//
// HTML only: `html.elem` contributes nothing at all on a paged target, element
// and children alike. That is the same trade every view here makes.
#import "@rookery/core:0.1.1": _bind, _LIG-IDEA
#import "graph.typ": *
#import "target.typ": *

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

// Binds this todo's recompile to every dep it names that resolves to a real
// note — OPEN OR CLOSED, since a dep closing or reopening changes what
// `#todo-blocked-by` shows even on a run where the OPEN set itself does not
// change.
//
// A SEPARATE FUNCTION from `#todo-blocked-by`, called once at `#todo`'s own
// call site rather than folded into the note's transcluded body: that body
// is replayed verbatim wherever the note is shown — inline at the call site
// AND on the note's own minted page — and a minted page is never a member of
// rheo's known vertebrae (core's own `_idea-ligaments` draws the same line,
// for the same reason: see `state.typ`'s comment on `page: rec.origin`). A
// bind read from inside the replayed body would, on the minted-page replay,
// attach to a handle ligaments cannot resolve and get silently dropped as
// malformed. Read once, at the call site, `state("rheo-handle")` names the
// vertebra the call was WRITTEN in — rebuilding that vertebra is what
// re-mints the note's page anyway.
#let todo-dep-binds(deps) = if deps.len() > 0 {
  context {
    if _is-markup() and type(state("rheo-handle").get()) == str {
      let graph = todo-graph()
      deps
        .filter(d => d in graph.nodes)
        .map(d => _bind(_LIG-IDEA + graph.nodes.at(d).id))
        .join()
    }
  }
}
