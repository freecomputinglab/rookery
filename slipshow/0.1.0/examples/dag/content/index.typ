// `@rookery/todos`' `layers()` groups a dependency graph into layer 0, 1,
// 2, .. by longest path — nodes on one layer depend on the layer(s) below
// and on nothing from each other, which is exactly what belongs BESIDE
// itself on one screen rather than flattened into a scrolling list. This
// page is that: one `#slipshow` row per layer, four layers deep (see
// `content/corpus.typ` for the fourteen todos and the shape they form).
//
// `#slipshow`'s `row:` computes the row straight from the graph — no
// `#todo` carries a `slip-row` tag, and no build-time assertion is needed to
// keep one in sync with the graph, because there is nothing left to drift.
//
// TWO WRAPPER-BASED ROUTES WERE TRIED FIRST AND BOTH FAILED, worth recording
// so nobody re-discovers it the hard way. Wrapping every todo inline —
// `slip(name, row: layer.at(name))[#window(name)]` — collides: the todo's
// own name is already registered under `idea:<name>`, and a second
// registration under that id with different tags panics as a duplicate
// (`core/0.1.0/src/idea.typ`'s `_registry.update`). Dropping to an auto id
// avoids that particular collision but panics differently: deciding which
// todos to wrap means reading `todo-graph()`'s `.final()` registry, which is
// not settled until every note on the page — wrapper ideas included — has
// been placed once, so Typst reruns layout to converge. Each rerun
// re-registers the auto-id wrapper from the counter's start and lands on
// the SAME id with DIFFERENT content across runs, which panics as a
// duplicate too. `row:` exists because neither wrapper shape works: it
// hands a computed row straight to a todo's own existing registration
// instead of creating a second one. (`content/wide.typ` still wraps its
// todos — its row is a page-local override, not a graph fact, so a second,
// pinned-name registration is the right shape there.)
#import "lib.typ": template, todo-graph, layer-of, priority-of, slipshow
#show: template

= Organizing the retreat, horizontally

#context {
  let layer = layer-of(todo-graph())
  slipshow(
    tags: "todo",
    row: r => layer.at(r.name, default: none),
    // One flat tag query, ordered by a single string key that sorts row
    // first (dominant digit), then priority (unprioritised last, encoded as
    // 9), then name — `order:`'s key function must return ONE comparable
    // value per row (`src/select.typ`), so the three-part sort is folded
    // into one string rather than expressed as a tuple.
    order: r => {
      let p = priority-of(r.tags-dict)
      str(layer.at(r.name, default: 9)) + str(if p == none { 9 } else { p }) + r.name
    },
  )
}
