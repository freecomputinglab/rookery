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
// page needs happens here, over the sliced rows, before naming them. `row:`
// has no such restriction — it groups, it does not reorder — so it composes
// with `slips:` the same way it composes with a tag query on
// `content/index.typ`. `layer-of` runs on the FULL graph, closed todos
// included, so a slice's row numbers agree with the unsliced deck's.
#import "lib.typ": template, todo-graph, graph-slice, layer-of, priority-of, slipshow
#show: template

= The same DAG, open todos only

#context {
  let graph = todo-graph()
  let layer = layer-of(graph)
  let sliced = graph-slice(graph, closed: false)
  let key(r) = {
    let p = priority-of(r.tags-dict)
    str(layer.at(r.name, default: 9)) + str(if p == none { 9 } else { p }) + r.name
  }
  let ordered = sliced.rows.sorted(key: key)
  slipshow(slips: ordered.map(r => r.name), row: r => layer.at(r.name, default: none))
}
