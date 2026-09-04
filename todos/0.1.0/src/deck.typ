// `#todo-slipshow` — the todo graph, laid out as an `@rookery/slipshow` deck.
//
// THIS FILE IS THE ONE IMPORT EDGE TO @rookery/slipshow, and it mirrors
// `panel.typ`'s edge to @rookery/search for the same reason: `dfs-of`,
// `is-ready` and `is-blocked` derive in THIS package and nowhere else
// (`graph.typ`), so a deck that cannot read them is the thing every
// consuming site hand-rolls — see `slipshow/0.1.0/examples/dag/content/
// index.typ`, which composes them by hand into an `order:`/`row:` pair. This
// costs every OTHER consumer of this package nothing: asset shipping follows
// a project's own imports, not a package's internal ones, so a project using
// `#todo-slipshow` still imports `@rookery/slipshow` itself to get that
// package's CSS and JS, exactly as it already must import @rookery/search
// for `#filter-panel`.
//
// `todo-slip-keys`' `row:` AND `order:` ARE A MATCHED PAIR, not two
// independent options. `order:` is the depth-first position `dfs-of`
// (`graph.typ`) emits, precisely so `#slipshow`'s `_row-runs` — which groups
// CONSECUTIVE entries and never reorders — sees each sibling group adjacent;
// passing `row:` with no such `order:` fragments every group into singleton
// rows instead of a horizontal run.
//
// `direction:` decides the one thing the two deck shapes disagree about:
// `"down"` (the default) gives every dependency-free todo a group of its own
// so they stack, `"across"` makes them one group so they span a row. The
// todos a single parent releases share a row in both.

#import "@rookery/slipshow:0.1.0": slipshow
#import "graph.typ": *
#import "tags.typ": *

// Zero-pads `s` with leading zeros to width `w`. Typst has no string-repeat
// operator, and without this a deck of more than nine slips breaks `order`'s
// sort: the plain string "10" sorts before "2".
#let _pad(s, w) = {
  let out = s
  while out.len() < w { out = "0" + out }
  out
}

// The four `#slipshow` key functions (`row:`, `order:`, `class:`, `edges:`) a
// todo deck needs, each over an `ideas(values: true)` REGISTRY
// ROW — the shape `#slipshow` hands a key function. A registry row carries
// `id`, `name`, `title`, `text`, `label`, `tags`, `tags-dict`, `body`,
// `href`, `page` and `created`; it does NOT carry `deps`, `closed` or
// `priority`, which only the `todos()` rows inside `graph.nodes` have. So
// every function below looks the note up by name first and returns `none`
// when it is absent — which is what a slip that is not a todo gets: no row,
// no class, and no sort key, so it joins no row and sorts last regardless of
// `reverse:` (`select.typ`'s `_sort-pairs`).
//
// A NON-TODO SLIP IN ONE OF THESE DECKS THEREFORE LOSES ITS OWN `slip-class`
// TAG, and that is the one place these keys are lossy. `class:` overrides a
// tag by KEY PRESENCE rather than value (`select.typ`'s `_apply-class`), and
// the key lands on every queried entry the function ran on — so `none` here
// means "no class", not "leave the tag alone", and a key function has no way
// to say the latter. A deck mixing an authored, classed slide in among its
// todos passes its own `class:` to `#todo-slipshow`, which wins outright.
#let todo-slip-keys(graph, today: none, done: "inline", direction: "down") = {
  assert(
    done in ("inline", "first", "last"),
    message: "@rookery/todos: `done` must be \"inline\", \"first\", or "
      + "\"last\" — got " + repr(done),
  )
  assert(
    direction in ("down", "across"),
    message: "@rookery/todos: `direction` must be \"down\" or \"across\" — got "
      + repr(direction),
  )

  // Computed ONCE, not per call: the walk covers the whole graph, and every
  // slip in the deck asks it the same question.
  let walk = dfs-of(graph, roots-together: direction == "across")
  let width = str(walk.order.len()).len()

  // Group id -> member count. Dictionary keys are strings in Typst, so the
  // int id is stringified to index this and nothing else.
  let sizes = (:)
  for (_, gid) in walk.group {
    sizes.insert(str(gid), sizes.at(str(gid), default: 0) + 1)
  }

  // A GROUP OF ONE GETS NO ROW. `#slipshow` gives a `none`-row entry no
  // `div.slip-row` wrapper at all (`slipshow.typ`), which is what makes a
  // "down" deck stack: every dependency-free todo is its own group there, and
  // so is the only todo a parent releases.
  let row(r) = {
    let gid = walk.group.at(r.name, default: none)
    if gid == none or sizes.at(str(gid)) == 1 { return none }
    gid
  }

  let order(r) = {
    let n = graph.nodes.at(r.name, default: none)
    if n == none { return none }
    let key = _pad(str(walk.order.at(r.name)), width)
    if done == "inline" { return key }
    // `first`/`last` sort by closedness before anything else: a "0" prefix
    // sorts ahead of a "1" one, so which digit a closed note gets is what
    // decides whether it leads or trails the deck.
    let closed-digit = if done == "first" { "0" } else { "1" }
    let open-digit = if done == "first" { "1" } else { "0" }
    (if n.closed { closed-digit } else { open-digit }) + key
  }

  let class(r) = {
    let n = graph.nodes.at(r.name, default: none)
    if n == none { return none }
    if n.closed { "todo-slip-closed" }
    else if is-blocked(n, graph) { "todo-slip-blocked" }
    else if is-ready(n, graph, today: today) { "todo-slip-ready" }
    // A fourth, real case that stays unstyled: an open todo neither blocked
    // nor ready is one DEFERRED past `today` by @rookery/timeline's
    // `scheduled` stage (see `is-ready`), and it gets no class rather than a
    // fourth colour.
    else { none }
  }

  // The todos this one WAITS ON, as `#slipshow`'s `edges:` — so a blocked
  // slide's rail is fed by a curve down from each dependency's.
  //
  // `blockers-of` (`graph.typ`) IS EXACTLY THE RIGHT READER and `n.deps` is
  // not: it keeps the deps that exist AND are still open, which is what makes
  // both silences below correct.
  //
  //   - A SATISFIED dependency draws no curve. `graph-slice` keeps that same
  //     rule for the graph view — an edge into a closed todo would point at a
  //     box that is not on the page — and here it would point at a greyed-out
  //     slide and claim something is waiting on work that is already done.
  //   - A DANGLING dep draws none either: it names nothing that could ever
  //     close, which is the same reason `is-blocked` does not let one block a
  //     todo.
  //
  // The source of every curve is therefore an OPEN todo, and that is why a
  // curve is only ever green-to-red or red-to-red: `class` gives an open,
  // unblocked blocker `todo-slip-ready` and an open, blocked one
  // `todo-slip-blocked`.
  let edges(r) = {
    let n = graph.nodes.at(r.name, default: none)
    if n == none { return none }
    blockers-of(n, graph)
  }

  (row: row, order: order, class: class, edges: edges)
}

// `#slipshow`, fed the todo graph's own `row:`/`order:`/`class:`/`edges:` so
// a call site does not compose them by hand. `..args` takes only named
// arguments — `#slipshow` itself has no positional parameter for them to
// fill — and
// `today:`/`done:`/`direction:` are this wrapper's own, consumed by
// `todo-slip-keys` rather than forwarded: `#slipshow` has none of the three.
#let todo-slipshow(..args, today: none, done: "inline", direction: "down") = context {
  assert(
    args.pos().len() == 0,
    message: "@rookery/todos: #todo-slipshow takes only named arguments — "
      + "#slipshow itself takes none positionally.",
  )
  let named = args.named()

  let graph = todo-graph()
  assert-acyclic(graph)
  let keys = todo-slip-keys(graph, today: today, done: done, direction: direction)

  // `resolve-slips` refuses `order:` alongside `slips:` outright — an
  // explicit array is already in the order it was written — so the derived
  // `order:` has to be dropped before an otherwise-legal `slips:` call
  // panics on it. `row:`, `class:` and `edges:` stay: all three compose with
  // `slips:`, since none of them selects or reorders anything.
  if "slips" in named {
    let _ = keys.remove("order")
  }

  // No selection named at all is the whole todo corpus, as a DAG deck.
  if "slips" not in named and "tags" not in named and "where" not in named {
    named.insert("tags", TODO-KEY)
  }

  // ONE dictionary, not two spreads: `+` is right-wins, so a caller's own
  // `row:`/`order:`/`class:`/`edges:` overrides the derived one, and two
  // separate `..keys, ..named` spreads would instead be a duplicate-argument
  // error the moment a caller named any of the same keys.
  slipshow(..(keys + named))
}
