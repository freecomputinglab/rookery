// `@rookery/todos`' `layers()` groups a dependency graph into layer 0, 1,
// 2, .. by longest path — nodes on one layer depend on the layer(s) below
// and on nothing from each other, which is exactly what belongs BESIDE
// itself on one screen rather than flattened into a scrolling list. This
// page is that: one `#slipshow` row per layer, four layers deep (see
// `content/corpus.typ` for the fourteen todos and the shape they form).
//
// ROUTE (a), of the two ways to get a computed row value onto a slip that
// carries no `row:` of its own: `content/corpus.typ` hand-writes a
// `slip-row` tag on every `#todo`, matching its layer, and `#slipshow`
// below reads it straight off the note the way it reads any other tag.
//
// Route (b) — wrapping every todo in an inline
// `#slip(.., row: i, max-width: ..)[#window(name)]` — was tried and
// dropped. Passing the todo's OWN name to that wrapper collides with the
// todo's own pinned id: `@rookery/core` registers both under the same
// `idea:<name>`, and a second registration with different tags panics as a
// duplicate (`core/0.1.0/src/idea.typ`'s `_registry.update`). Dropping the
// name for an auto id avoids that particular collision but MEASURED WORSE
// here: deciding which row a wrapper belongs to means reading
// `todo-graph()`'s `.final()` registry, which is not settled until every
// note on the page — wrapper ideas included — has been placed once, so
// Typst reruns layout to converge it. Each rerun re-registers the auto-id
// wrappers from the counter's start and lands on the SAME id with
// DIFFERENT content across runs, which panics as a duplicate
// (`content/wide.typ`'s header carries the full trace of this failure). A
// pinned, distinct wrapper name sidesteps that crash — `content/wide.typ`
// uses one — but then every todo needs a SECOND registry entry just to
// carry a row it could carry itself. `content/wide.typ` pays that price
// because its row is a one-page-only override of what the graph says; this
// page's row IS what the graph says, so the graph's own node is where it
// belongs.
//
// THE ASSERTION BELOW is what keeps route (a) honest: a hand-written
// `slip-row` can drift from the graph it is supposed to describe the moment
// `content/corpus.typ` changes without a matching update here, and this
// fails the build the instant that happens rather than shipping a deck that
// misrepresents its own DAG.
#import "lib.typ": template, todo-graph, layer-of, priority-of, slipshow, row-of
#show: template

= Organizing the retreat, horizontally

#context {
  let graph = todo-graph()
  let layer = layer-of(graph)
  for (name, row) in graph.nodes {
    let declared = row-of(row.tags-dict)
    assert(
      declared == layer.at(name),
      message: "examples/dag: \"" + name + "\" declares slip-row "
        + repr(declared) + " but its computed layer is "
        + repr(layer.at(name)) + " — update content/corpus.typ.",
    )
  }
}

// One flat tag query, ordered by a single string key that sorts row first
// (dominant digit), then priority (unprioritised last, encoded as 9), then
// name — `order:`'s key function must return ONE comparable value per row
// (`src/select.typ`), so the three-part sort is folded into one string
// rather than expressed as a tuple.
#slipshow(
  tags: "todo",
  order: r => {
    let p = priority-of(r.tags-dict)
    str(row-of(r.tags-dict)) + str(if p == none { 9 } else { p }) + r.name
  },
)
