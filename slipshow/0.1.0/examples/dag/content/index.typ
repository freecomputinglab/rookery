// `@rookery/todos`' `layers()` groups a dependency graph into layer 0, 1,
// 2, .. by longest path — nodes on one layer depend on the layer(s) below
// and on nothing from each other, which is exactly what belongs BESIDE
// itself on one screen rather than flattened into a scrolling list. This
// page is that: one `#slipshow` row per layer, four layers deep (see
// `content/corpus.typ` for the fourteen todos and the shape they form).
//
// THE WHOLE PAGE IS ONE `#todo-slipshow` CALL. The row each slide joins, the
// within-layer order (priority then name, unprioritised last) and the
// status rail (ready/blocked/closed) all come straight from
// `todo-slip-keys` inside `@rookery/todos`' `deck.typ` — this page hands it
// nothing but the tag query selecting every todo, and has no `row:`/
// `order:`/`class:` of its own to keep in sync with the graph.
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
#import "lib.typ": template, todo-slipshow
#show: template

= Organizing the retreat, horizontally

#todo-slipshow(tags: "todo")
