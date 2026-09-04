// The corpus, the dependency graph over it, and the checks that keep it a DAG.
//
// Nothing here renders. `views.typ` is the rendering half; this file is the
// data and the validation, so a project can build its own views on the same
// footing the shipped ones stand on.

#import "@rookery/core:0.1.0": ideas, tag-data
#import "@rookery/timeline:0.1.0": is-scheduled-now, scheduled-of
#import "target.typ": *
#import "tags.typ": *

// ---- todos() — every todo in the rookery, joined with its tag values ------
//
//   #context todos()
//
// One row per note carrying the `todo` key, each carrying rookery's own row
// fields (id, name, title, text, label, href, page, created) plus this
// package's decoded attributes and the raw tag dictionary.
//
// TWO BULK READS, NOT N SMALL ONES, and that is deliberate. `ideas()` resolves
// the registry once for the whole corpus and `tag-data()` does the same for the
// tag store; joining them on `id` costs nothing. Reaching for `tags-of` or
// `tag-value` per row instead would pay one registry resolution PER NOTE — a
// cost rookery's own `data.typ` documents explicitly against `tags-of`.
//
// Must be called INSIDE a `#context` block: `ideas()` and `tag-data()` both
// read `.final()`. Like them, it is not itself a context function, because a
// context function may only return content and the whole point is to return
// data.
#let todos() = {
  let store = tag-data()
  ideas()
    .map(e => {
      let tags = store.at(e.id, default: (:))
      (
        ..e,
        tags-dict: tags,
        priority: priority-of(tags),
        kind: type-of(tags),
        status: status-of(tags),
        closed: is-closed(tags),
        closed-on: closed-on(tags),
        deps: deps-of(tags),
        metadata: metadata-of(tags),
      )
    })
    .filter(t => is-todo(t.tags-dict))
}

// ---- todo-graph() — adjacency over `todo-deps` ----------------------------
//
// Returns `(nodes: (name -> row), edges: ((from, to), ..), unresolved: ((from,
// dep), ..))`, where an edge runs FROM a todo TO something it depends on.
//
// Keyed by `name` — the id with rookery's prefix stripped — because that is
// what an author writes in `deps: ("fetch",)` and what rookery's `_norm` maps
// every accepted form onto. Deps were already normalized at write time
// (`todo-tags`), so no id arithmetic happens here: matching is a dictionary
// lookup against the rows `todos()` returned. Do NOT rebuild ids with rookery's
// `_pfx()` — it is contextual state, and the rows already carry both forms.
//
// A DANGLING DEP IS NOT AN ERROR. It is collected into `unresolved` and left
// for a view to render as such. This follows the precedent rookery sets with
// `tags-of`, where an unknown id answers emptily rather than panicking: a
// caller asking about dependencies is describing a graph, not dereferencing a
// pointer, and a description that dies on the first typo is useless.
#let todo-graph(rows: none) = {
  let rows = if rows == none { todos() } else { rows }
  let nodes = rows.map(t => (t.name, t)).to-dict()
  let edges = ()
  let unresolved = ()
  for t in rows {
    for d in t.deps {
      if d in nodes { edges.push((t.name, d)) } else { unresolved.push((t.name, d)) }
    }
  }
  (nodes: nodes, edges: edges, unresolved: unresolved)
}

// ---- cycle detection ------------------------------------------------------
//
// A depth-first walk colouring each node white/grey/black. A grey node reached
// again is a back edge, i.e. a cycle, and the grey stack at that moment IS the
// cycle path — which is what makes the error message name the actual loop
// rather than merely assert one exists.
//
// Iterative rather than recursive: Typst has a recursion depth limit and a
// rookery is not bounded in size, so a deep chain must not be the thing that
// breaks first.
//
// Returns the cycle as an array of names (first name repeated at the end), or
// `()` when the graph is acyclic.
#let find-cycle(graph) = {
  let adj = (:)
  for name in graph.nodes.keys() { adj.insert(name, ()) }
  for e in graph.edges { adj.insert(e.at(0), adj.at(e.at(0)) + (e.at(1),)) }

  let colour = (:)
  for name in adj.keys() { colour.insert(name, "white") }

  for root in adj.keys() {
    if colour.at(root) != "white" { continue }
    // Each frame is (node, index of the next child to visit).
    let stack = ((root, 0),)
    colour.insert(root, "grey")
    while stack.len() > 0 {
      let (node, i) = stack.last()
      let kids = adj.at(node)
      if i >= kids.len() {
        colour.insert(node, "black")
        let _ = stack.pop()
        continue
      }
      stack.at(stack.len() - 1) = (node, i + 1)
      let kid = kids.at(i)
      let c = colour.at(kid, default: "white")
      if c == "grey" {
        // Back edge. The cycle is the grey stack from `kid` onward, closed by
        // `kid` again.
        let path = stack.map(f => f.at(0))
        let start = path.position(n => n == kid)
        return path.slice(start) + (kid,)
      }
      if c == "white" {
        colour.insert(kid, "grey")
        stack.push((kid, 0))
      }
    }
  }
  ()
}

// Panics naming the full cycle path when there is one. Every view in this
// package calls this before rendering.
//
// WHY IT CANNOT RUN AT THE `#todo` CALL SITE, which is what you might expect:
// `#todo("a", deps: ("b",))` is perfectly legal before `b` exists, and the
// graph only exists once the registry is final. There is no moment during
// authoring at which a cycle is visible. So the guarantee is assembled from two
// halves instead — every view checks, and `#todos-validate()` below lets a
// project that renders no view check anyway. Between them a cycle cannot
// survive a build.
#let assert-acyclic(graph) = {
  let cycle = find-cycle(graph)
  if cycle.len() > 0 {
    panic(
      "@rookery/todos: dependency cycle: " + cycle.join(" -> ")
        + ". Todos are networked purely through `deps:`, so this graph has no "
        + "order to render — break the loop by removing one of these edges.",
    )
  }
}

// ---- derived state — computed at render, never stored ---------------------
//
// `blocked`, `ready` and `stale` are questions about the graph and the calendar
// as they stand right now, not facts about a note. Tagging them would let them
// drift out of step with the deps and dates that define them, and nothing would
// report the drift.

// Blocked: at least one dependency exists and is not yet closed. An UNRESOLVED
// dep does not block — it names nothing, so it can never close, and treating it
// as a blocker would wedge a todo forever on a typo.
#let is-blocked(row, graph) = row.deps.any(d => {
  let dep = graph.nodes.at(d, default: none)
  dep != none and not dep.closed
})

// Which dependencies are blocking, for a view that wants to say why.
#let blockers-of(row, graph) = row.deps.filter(d => {
  let dep = graph.nodes.at(d, default: none)
  dep != none and not dep.closed
})

// Ready: open, unblocked, and not deferred past the reference date.
//
// THE DEFERRAL CLAUSE IS WHAT MAKES THIS br's `ready` RATHER THAN MERELY "not
// blocked". A todo scheduled for next week is not work you can pick up now.
// Deferral is read from @rookery/timeline's `scheduled` log stage, so scheduling
// stays one concept owned by one package rather than two that can disagree.
//
// A todo with NO `scheduled` entry is not deferred — absence of a plan is not a
// plan to wait, which is why this asks `scheduled-of(..) == none or ..` rather
// than `is-scheduled-now(..)` alone.
//
// `today:` is passed through to rookery-timeline, which resolves it against the
// document date and panics if neither is available. NOTHING HERE CALLS
// `datetime.today()`: it returns 1980-01-01 under a reproducible build and does
// not error while doing it.
#let is-ready(row, graph, today: none) = {
  if row.closed { return false }
  if is-blocked(row, graph) { return false }
  let sched = scheduled-of(row.tags-dict)
  sched == none or is-scheduled-now(row.tags-dict, today: today)
}

// ---- #todos-validate() — fail the build on a broken graph -----------------
//
// Drop it at bundle root in a project that renders no todo view, so a cycle
// still cannot ship. Renders nothing.
//
// Also REPORTS what cannot be a warning. Typst gives package code no `warn()`,
// only `panic`, so the auto-id dependency smell — a dep naming an unpinned,
// sequence-numbered note, whose number shifts when a note is inserted earlier
// in the spine — has nowhere else to surface. `strict: true` turns it into an
// error for a project that wants the stricter rule; the default reports it in
// the compiled output rather than failing a build that has not actually broken.
#let todos-validate(strict: false) = context {
  let graph = todo-graph()
  assert-acyclic(graph)

  let numeric = ()
  for (name, row) in graph.nodes {
    for d in row.deps {
      // An auto id is rookery's counter value: digits and nothing else.
      if d.len() > 0 and d.clusters().all(c => c in ("0", "1", "2", "3", "4", "5", "6", "7", "8", "9")) {
        numeric.push(name + " -> " + d)
      }
    }
  }

  let problems = ()
  if numeric.len() > 0 {
    problems.push(
      "depends on an auto-numbered note, whose id shifts when a note is "
        + "inserted earlier in the spine — pin it with `#todo(\"name\")`: "
        + numeric.join(", "),
    )
  }
  if graph.unresolved.len() > 0 {
    problems.push(
      "depends on a note that does not exist: "
        + graph.unresolved.map(p => p.at(0) + " -> " + p.at(1)).join(", "),
    )
  }

  if problems.len() == 0 { return }
  let msg = "@rookery/todos: " + problems.join("; ")
  if strict { panic(msg) } else {
    html.elem("div", attrs: (class: "todo-validate-report", hidden: "hidden"), msg)
  }
}

// ---- graph-slice — what a view should actually draw ------------------------
//
// `closed: false` keeps only open rows, and only edges with BOTH ends open. An
// edge into a closed todo is a SATISFIED dependency, and drawing it would point
// at a box that is not on the page.
//
// A pure function of the graph, deliberately: it is what makes `closed:`
// testable without a DOM or a rookery registry, and it is exported so a project
// building its own view stands on the same footing this file's header claims to
// offer.
#let graph-slice(graph, closed: true) = {
  if closed { return (rows: graph.nodes.values(), edges: graph.edges) }
  let rows = graph.nodes.values().filter(r => not r.closed)
  let open-names = rows.map(r => r.name)
  (
    rows: rows,
    edges: graph.edges.filter(e => e.at(0) in open-names and e.at(1) in open-names),
  )
}

// ---- layer-of / layers — longest-path layering, at build time -------------
//
// The Typst twin of `layer`/`rows` in `src/layout.js`, which lays out the
// same graph for `#todo-graph-view`'s browser-side drawing. A node's layer is
// one more than the deepest layer among the things it depends on: layer 0
// depends on nothing — work that is unblocked — and layer n holds what those
// release. LONGEST path rather than shortest, because with shortest-path
// layering an edge can span several layers, and with longest-path every edge
// is exactly one layer long. The two cannot be changed apart.
//
// ITERATIVE WITH A BOUNDED WORKLIST, not recursive, for the reason
// `find-cycle` above already gives: Typst has a recursion depth limit and a
// rookery is not bounded in size. Bounded at `graph.nodes.len() + 1` passes,
// matching `layout.js`, so a bad input degrades to a wrong grouping rather
// than a hang.
//
// A dep naming a node outside `graph.nodes` contributes nothing here, the
// same way it contributes no edge to `graph.edges` — it is `unresolved`, not
// a layering input.
//
// A pure function of the graph, not a context function: the caller is what
// sits inside `#context`, the same split `todo-graph` documents above.
// Named with the `-of` suffix this file's other readers use (`deps-of`,
// `priority-of`) rather than the bare `layer` its JavaScript twin uses,
// because a bare `layer` in package scope is a name a consuming project
// could plausibly want for itself.
#let layer-of(graph) = {
  assert-acyclic(graph)

  let deps = (:)
  for name in graph.nodes.keys() { deps.insert(name, ()) }
  for e in graph.edges { deps.insert(e.at(0), deps.at(e.at(0)) + (e.at(1),)) }

  let layer = (:)
  for name in graph.nodes.keys() { layer.insert(name, 0) }

  let limit = graph.nodes.len() + 1
  for _ in range(limit) {
    let changed = false
    for name in graph.nodes.keys() {
      let want = deps.at(name).fold(0, (acc, d) => {
        if d in layer { calc.max(acc, layer.at(d) + 1) } else { acc }
      })
      if want > layer.at(name) {
        layer.insert(name, want)
        changed = true
      }
    }
    if not changed { break }
  }
  layer
}

// The sort key for a list of sibling nodes: priority ascending, then name,
// with an unprioritised node last. `layers` and `dfs-of` both order by it, and
// it matches `layout.js`'s `rows()` and the list views, so the drawn graph and
// a deck built from the same data agree about sequence.
#let _rank(r) = (
  if r.at("priority", default: none) == none { 9 } else { r.priority },
  r.name,
)

// Groups `graph.nodes.values()` into an array of arrays by `layer-of(graph)`,
// index = layer, layer 0 first — the nodes on the same layer are the notes the
// drawn graph puts on one line: several todos depending on the same parent and
// on nothing from each other.
#let layers(graph) = {
  let layer = layer-of(graph)
  let max-layer = layer.values().fold(-1, (m, l) => calc.max(m, l))
  range(max-layer + 1).map(l => graph.nodes
    .values()
    .filter(r => layer.at(r.name) == l)
    .sorted(key: _rank))
}

// ---- dfs-of — a deck's reading order, depth-first -------------------------
//
// A depth-first walk of the graph `layer-of` layers, returning
// `(order: (name -> int), group: (name -> int))` — a node's position in the
// emitted sequence, and the id of the contiguous run of siblings it was
// emitted with. Both carry one entry per node in `graph.nodes`.
//
// DEPTH-FIRST IS WHAT KEEPS A CONNECTOR CURVE SHORT. Reading the graph layer
// by layer puts every other node of a layer between a todo and the ones it
// releases; following one branch to its end puts them beside each other.
//
// A GROUP IS THE TODOS ONE PARENT RELEASES, emitted adjacently so
// `#slipshow`'s `_row-runs` — which groups CONSECUTIVE entries and never
// reorders — can lay them out side by side. Group ids are distinct ints;
// nothing reads one as an index.
//
// `roots-together` is the one thing the two deck directions disagree about:
// with it the dependency-free nodes are a single group and span a row,
// without it each is a group of one and they stack. Everything they release
// is emitted identically either way. A root is a node with no dependency
// INSIDE the graph, so a todo whose only dep dangles is one — the same rule
// that makes a dangling dep no layering input and no blocker.
//
// Iterative with an explicit worklist rather than recursive, for the reason
// `find-cycle` and `layer-of` above both give: Typst has a recursion depth
// limit and a rookery is not bounded in size. Taking from the front of that
// worklist and pushing onto the front is what makes the walk depth-first;
// pushing onto the back instead is the layering `layer-of` already provides.
#let dfs-of(graph, roots-together: false) = {
  assert-acyclic(graph)

  // Name -> the names that DEPEND on it, the reverse of `graph.edges`, whose
  // pairs run from a todo to what it depends on. Every edge has both ends in
  // `graph.nodes` (`todo-graph` sorts a dangling dep into `unresolved`
  // instead), so no membership check is needed on either side.
  let kids = (:)
  for name in graph.nodes.keys() { kids.insert(name, ()) }
  let has-dep = (:)
  for e in graph.edges {
    kids.insert(e.at(1), kids.at(e.at(1)) + (e.at(0),))
    has-dep.insert(e.at(0), true)
  }

  let ranked = names => names.map(n => graph.nodes.at(n)).sorted(key: _rank).map(r => r.name)
  let roots = ranked(graph.nodes.keys().filter(n => n not in has-dep))

  let order = (:)
  let group = (:)
  let g = 0
  let i = 0

  if roots-together {
    for n in roots {
      order.insert(n, i)
      group.insert(n, g)
      i += 1
    }
  }

  for r in roots {
    if not roots-together {
      g += 1
      order.insert(r, i)
      group.insert(r, g)
      i += 1
    }
    let worklist = (r,)
    while worklist.len() > 0 {
      let m = worklist.remove(0)
      // Unvisited at EXPANSION time, not at queue time: a todo released by two
      // parents is emitted once, under whichever of them expands first.
      let fresh = ranked(kids.at(m).filter(k => k not in order))
      if fresh.len() > 0 {
        g += 1
        for k in fresh {
          order.insert(k, i)
          group.insert(k, g)
          i += 1
        }
        worklist = fresh + worklist
      }
    }
  }

  // A node reachable from no root cannot exist in an acyclic graph, and a deck
  // that silently lost a slide would be worse than a build that stops.
  assert(
    order.len() == graph.nodes.len(),
    message: "@rookery/todos: dfs-of did not reach every node",
  )
  (order: order, group: group)
}

// ---- #todo-graph-view — the DAG, as a page element ------------------------
//
// Emits a container plus a `<script type="application/json">` payload holding
// the graph, which `todos.js` lays out and draws client-side. Same
// shape @rookery/search uses for its search index, and for the same
// reason: Typst has no layout engine for a directed graph, and a JSON payload
// beside the element it belongs to is the cheapest handoff there is.
//
// THE PAYLOAD IS JSON-SAFE BY CONSTRUCTION — strings, numbers, booleans and
// arrays only, never a raw tag value. A value can be a `datetime` or content,
// and MEASURED: `json.encode` of content does NOT error, it silently emits a
// structural blob like `{"func":"text","text":"hi"}`. That would bloat the page
// rather than fail loudly, so dates are stamped to `[year][month][day]` strings
// here — the same convention rookery-search already uses — and the metadata bag
// is left out entirely.
//
// DEGRADES WITHOUT JAVASCRIPT. The container ships the node list as ordinary
// linked markup, which the script replaces once it runs. A reader with JS off,
// and every paged or EPUB target, still gets the todos and their dependencies
// as readable text rather than an empty box.
#let todo-graph-view(title: none, today: none, closed: true) = context {
  let graph = todo-graph()
  // A cyclic graph has no layered layout, and a cycle is already a build error
  // — this is the view half of that guarantee.
  assert-acyclic(graph)

  // ONE slice, feeding all three renderings — the paged branch, the JSON
  // payload and the no-JS fallback — so they cannot disagree about what is on
  // the page. Before this they each reached for their own source.
  let (rows, edges) = graph-slice(graph, closed: closed)

  // The dep names still on the page, for the "depends on ..." notes below.
  // Naming a dependency whose box the SLICE removed is exactly what the edge
  // filter exists to prevent, so the prose is filtered with it.
  //
  // A DANGLING DEP IS KEPT, and the distinction is the whole reason this reads
  // `d not in graph.nodes` rather than just `d in shown-names`. A dep naming a
  // note that does not exist never had a box to point at, in any slice — it was
  // named here before `closed:` existed and it still is, so `closed: true`
  // stays byte-identical to the output before this parameter. Filtering it too
  // would silently drop the only place a dangling dep surfaces in this view.
  // (`#todos-validate` reports it separately, and the graph payload still
  // carries it under `unresolved`.)
  let shown-names = rows.map(r => r.name)
  let shown-deps(r) = r.deps.filter(d => d not in graph.nodes or d in shown-names)

  // PAGED TARGET: there is no layout engine for a directed graph Typst-side
  // and no JavaScript to draw one, so the paged rendering IS the fallback list
  // the HTML branch already builds for readers with JS off. Same content, and
  // the only honest thing a PDF can show.
  //
  // `align(start)` for the reason rookery documents at `idea.typ`'s own paged
  // branch: a Typst figure centres its body, and this can sit inside one.
  if not _is-markup() {
    return align(start, {
      if title != none { strong(title); linebreak() }
      list(..rows.map(r => {
        let label = if r.text == "" { raw(r.name) } else { r.title }
        if r.closed { strike(label) } else { label }
        let d = shown-deps(r)
        if d.len() > 0 { [ #text(gray, "depends on " + d.join(", "))] }
      }))
    })
  }

  let stamp(d) = if d == none { none } else { d.display("[year][month][day]") }

  let nodes = rows.map(r => {
    let n = (
      name: r.name,
      id: r.id,
      title: if r.text == "" { r.name } else { r.text },
      status: if r.closed { "closed" } else if is-blocked(r, graph) {
        "blocked"
      } else if is-ready(r, graph, today: today) { "ready" } else { r.status },
    )
    if r.href != none { n.insert("href", r.href) }
    if r.priority != none { n.insert("priority", r.priority) }
    if r.kind != none { n.insert("type", r.kind) }
    let c = stamp(r.closed-on)
    if c != none { n.insert("closed", c) }
    n
  })

  let payload = (
    nodes: nodes,
    edges: edges.map(e => (from: e.at(0), to: e.at(1))),
    unresolved: graph.unresolved.map(e => (from: e.at(0), to: e.at(1))),
  )

  html.elem(
    "div",
    attrs: (class: "todo-graph"),
    {
      if title != none {
        html.elem("div", attrs: (class: "todo-view-title"), title)
      }
      html.elem(
        "script",
        attrs: (type: "application/json", class: "todo-graph-data"),
        json.encode(payload, pretty: false),
      )
      // The no-JS fallback, and the thing the script replaces.
      html.elem(
        "ul",
        attrs: (class: "todo-graph-fallback"),
        rows
          .map(r => {
            let label = if r.text == "" { r.name } else { r.text }
            html.elem(
              "li",
              attrs: (class: (("todo-graph-node",) + r.tags-dict.keys().map(k => "idea-tag-" + k)).join(" ")),
              {
                if r.href == none {
                  html.elem("span", attrs: (class: "todo-row-title"), label)
                } else {
                  html.elem("a", attrs: (class: "todo-row-title", href: r.href), label)
                }
                let d = shown-deps(r)
                if d.len() > 0 {
                  html.elem(
                    "span",
                    attrs: (class: "todo-row-note"),
                    "depends on " + d.join(", "),
                  )
                }
              },
            )
          })
          .join(),
      )
    },
  )
}
