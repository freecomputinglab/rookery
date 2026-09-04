// The same deck as `content/index.typ`, over `graph-slice(graph, closed:
// false)` instead of a bare tag query — proof that the layering is DERIVED
// from the graph rather than hardcoded on this page. `retire-legacy` is the
// corpus's one closed todo (`content/corpus.typ`), sitting alone in layer 0
// alongside four open siblings, so removing it narrows that layer by one
// without emptying it or disturbing the other three.
//
// `graph-slice` hands back rows and edges, not names, and `#slipshow`'s
// `slips:` wants an ordered array of names (or content) — `order:`/
// `reverse:` are refused alongside `slips:` because an explicit array is
// already in the order it was written (`src/select.typ`), so the sort this
// page needs happens here, over the sliced rows, before naming them.
// `row:`, `class:` and `edges:` have no such restriction — none of them
// selects or reorders anything — so all three compose with `slips:` the same
// way they compose with a tag query on `content/index.typ`.
//
// `row:`/`order:`/`class:`/`edges:` THEMSELVES ARE THE PACKAGE'S, not
// hand-rolled on this page: `todo-slip-keys(graph)` (`@rookery/todos`'
// `deck.typ`) returns the same four key functions `#todo-slipshow` feeds
// `#slipshow` on `content/index.typ`, computed once here into `keys` and
// reused for the sort, the row grouping, the status rail and the connector
// curves — `layer-of` runs on the FULL graph inside it, closed todos
// included, so a slice's row numbers agree with the unsliced deck's. The
// slice takes no edge with it either: the one todo it drops is closed, and a
// closed todo blocks nothing.
#import "lib.typ": template, todo-graph, graph-slice, todo-slip-keys, slipshow
#show: template

= The same DAG, open todos only

#context {
  let graph = todo-graph()
  let sliced = graph-slice(graph, closed: false)
  let keys = todo-slip-keys(graph)
  let ordered = sliced.rows.sorted(key: keys.order)
  slipshow(
    slips: ordered.map(r => r.name),
    row: keys.row,
    class: keys.class,
    edges: keys.edges,
  )
}
