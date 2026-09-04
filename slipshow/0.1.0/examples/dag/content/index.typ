// `@rookery/todos`' `dfs-of()` walks a dependency graph depth-first: one
// branch is followed to its end before the next starts, and the todos a
// single parent releases are emitted together as one group. That is what a
// deck wants — a todo sits next to the work it unblocks rather than a layer
// away from it, so the connector curve between them is short. This page is
// that walk over the fourteen todos in `content/corpus.typ`: `kickoff` and
// the four unrelated todos stack down the screen, and the four things
// `kickoff` releases span one row beside each other.
//
// `content/across.typ` is the same graph with `direction: "across"`, the one
// option that changes any of this.
//
// THE WHOLE PAGE IS ONE `#todo-slipshow` CALL. The row each slide joins, the
// sibling order (priority then name, unprioritised last) and the status rail
// (ready/blocked/closed) all come straight from `todo-slip-keys` inside
// `@rookery/todos`' `deck.typ` — this page hands it nothing but the tag query
// selecting every todo, and has no `row:`/`order:`/`class:` of its own to
// keep in sync with the graph.
//
// TWO WRAPPER-BASED ROUTES WERE TRIED FIRST AND BOTH FAILED, worth recording
// so nobody re-discovers it the hard way. Wrapping every todo inline —
// `slip(name, row: group.at(name))[#window(name)]` — collides: the todo's
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

= Organizing the retreat, down the screen

#todo-slipshow(tags: "todo")
