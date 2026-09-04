// Unit fixture for @rookery/todos' pure helpers. Run with `just test`
// from `rookery-todos/0.6.0`. No runner: an `assert` that fails fails the
// compile with a line number, and a passing compile is the green light.

#import "/src/lib.typ": *
// rookery-timeline is NOT re-exported by this package's lib, deliberately — a
// consumer imports it itself. The fixture does the same, for the derivations
// `TODO-LADDER` exists to feed.
#import "@rookery/timeline:0.1.0": entries, is-settled, next-stage, rung

#let d(y, m, dd) = datetime(year: y, month: m, day: dd)

// ---- todo-tags — the three surfaces ---------------------------------------

// Every todo carries the base key, and nothing else by default.
#assert.eq(todo-tags().keys(), ("todo",))

// FLAT keys encode their value in the key, so they stay filterable by
// `#window(tags:)` and by rookery-search's `tags:todo-p1`.
#assert.eq(todo-tags(priority: 1).keys(), ("todo", "todo-p1"))
#assert.eq(todo-tags(priority: 0).keys(), ("todo", "todo-p0"))
#assert.eq(todo-tags(kind: "bug").keys(), ("todo", "todo-bug"))
#assert.eq(todo-tags(status: "in-progress").keys(), ("todo", "todo-in-progress"))
// Flat means the value is `none`, which is what makes it render as a pill.
#assert.eq(todo-tags(priority: 1).at("todo-p1"), none)

// VALUED keys carry data and render no pill, but their KEY is still present,
// so `#window(tags: "todo-deps")` still finds them.
#assert.eq(todo-tags(deps: ("a", "b")).at("todo-deps"), ("a", "b"))
#assert.eq(todo-tags(metadata: (estimate: 30)).at("todo-metadata"), (estimate: 30))

// `closed` on `todo-tags` is a BOOL, and it is DERIVED: `#todo` passes
// `CLOSED-STAGE in log`, never a date. The date lives in the log alone. There is
// no `closed:` argument on `#todo` any more — a close is `timeline: (closed: d)`.
#assert.eq(todo-tags(closed: true).at("todo-closed"), none)
#assert.eq(todo-tags(closed: true).keys(), ("todo", "todo-closed"))
// `closed: false` emits NO KEY. A key valued `false` would read as closed to
// every consumer that tests for the key, including rookery's own tag filter.
#assert.eq(todo-tags(closed: false).keys(), ("todo",))


// EMPTY MEANS ABSENT for the valued keys — no meaningless class, no key that
// reads as "has dependencies, namely none".
#assert.eq(todo-tags(deps: ()).keys(), ("todo",))
#assert.eq(todo-tags(metadata: (:)).keys(), ("todo",))

// Deps are normalized through the injected normalizer, so a full id and a bare
// name land on the same string.
#assert.eq(
  todo-tags(deps: ("idea:a", "b"), norm: n => n.split(":").last()).at("todo-deps"),
  ("a", "b"),
)

// LABELS ARE PLAIN, UNNAMESPACED rookery tags — not a parameter of ours.
#assert.eq(todo-tags(tags: ("phd", "urgent")).keys(), ("todo", "phd", "urgent"))

// The caller's own tags merge LAST and win outright on a collision, with no
// deep merge. MEASURED: typst dictionary `+` is right-wins.
#assert.eq(todo-tags(priority: 1, tags: ("todo-p1": "mine")).at("todo-p1"), "mine")
#assert.eq(todo-tags(deps: ("a",), tags: ("todo-deps": ("z",))).at("todo-deps"), ("z",))

// ---- readers — decode, never store twice ----------------------------------
#assert.eq(is-todo(todo-tags()), true)
#assert.eq(is-todo((phd: none)), false)

#assert.eq(priority-of(todo-tags(priority: 3)), 3)
#assert.eq(priority-of(todo-tags()), none)
#assert.eq(type-of(todo-tags(kind: "feature")), "feature")
#assert.eq(type-of(todo-tags()), none)

#assert.eq(deps-of(todo-tags(deps: ("a",))), ("a",))
#assert.eq(deps-of(todo-tags()), ())
#assert.eq(metadata-of(todo-tags()), (:))

// THE LOG ALONE decides. The flat marker is an index into it, not a second
// source: with one write path the two cannot disagree, so `is-closed` reads the
// log and a marker without an entry (which `#todo` cannot produce) is not closed.
#assert.eq(is-closed(entries(timeline: (closed: d(2026, 8, 1)))), true)
#assert.eq(is-closed(todo-tags()), false)
#assert.eq(is-closed(todo-tags(closed: true)), false)
#assert.eq(closed-on(entries(timeline: (closed: d(2026, 8, 1)))), d(2026, 8, 1))

// ---- `done:` — the shorthand, folded into the same log --------------------
//
// `_closing` is the fold itself, tested here rather than through `#todo`: the
// latter mints a rookery note and needs a document, while the fold is a pure
// function of two arguments and is where every claim about `done:` lives.
//
// THE POINT OF EVERY ASSERT BELOW is that `done:` produces the SAME log as
// `timeline: (closed: ..)` — one write path, per this package's 0.6.0 note. The
// two refusals (`done: true`, and a close given twice) cannot be asserted on:
// Typst has no way to catch a panic, so they are covered by the messages in
// `todo.typ` and by reading them.
#assert.eq(_closing(none, none), none)
#assert.eq(_closing(none, (activated: d(2026, 8, 1))), (activated: d(2026, 8, 1)))
#assert.eq(_closing(d(2026, 8, 1), none), (closed: d(2026, 8, 1)))
// Folded INTO a timeline of other stages rather than replacing it.
#assert.eq(
  _closing(d(2026, 8, 2), (activated: d(2026, 8, 1))),
  (activated: d(2026, 8, 1), closed: d(2026, 8, 2)),
)
// An entry dictionary rides through untouched — that is how a close carries its
// own `note`, and rookery-timeline validates the shape, not this.
#assert.eq(
  _closing((timestamp: d(2026, 8, 1), note: [Landed.]), none).closed.timestamp,
  d(2026, 8, 1),
)
// The equivalence, end to end through the fragment: same tags, same readers.
#assert.eq(
  entries(timeline: _closing(d(2026, 8, 1), none)),
  entries(timeline: (closed: d(2026, 8, 1))),
)
#assert.eq(is-closed(entries(timeline: _closing(d(2026, 8, 1), none))), true)
#assert.eq(closed-on(entries(timeline: _closing(d(2026, 8, 1), none))), d(2026, 8, 1))

// `#done(date)` is a FACTORY, like `#epic` — it hands back a `#todo` variant, so
// what can be asserted without a document is that a function comes back at all.
#assert.eq(std.type(done(d(2026, 8, 1))), function)

// `status-of` — closed wins over a declared status, absent reads as open, and
// `blocked` never appears because it is derived from the graph, not declared.
#assert.eq(status-of(todo-tags()), "open")
#assert.eq(status-of(todo-tags(status: "draft")), "draft")
#assert.eq(status-of(todo-tags(closed: true) + entries(timeline: (closed: d(2026, 8, 1)))), "closed")
#assert.eq(status-of(todo-tags(status: "draft", closed: true) + entries(timeline: (closed: d(2026, 8, 1)))), "closed")

// ---- the graph, cycles, and derived state ---------------------------------
//
// Hand-built rows rather than a rookery registry: `todo-graph(rows: ..)` takes
// an injected corpus precisely so the graph logic can be tested without a
// document. The fields it reads are `name`, `deps`, `closed` and `tags-dict`.

#let row(name, deps: (), closed: false, tags: (:)) = (
  name: name,
  deps: deps,
  closed: closed,
  tags-dict: tags,
)

#let g(..rows) = todo-graph(rows: rows.pos())

// Edges run FROM a todo TO what it depends on.
#let simple = g(row("a"), row("b", deps: ("a",)))
#assert.eq(simple.edges, (("b", "a"),))
#assert.eq(simple.unresolved, ())
#assert.eq(simple.nodes.keys().sorted(), ("a", "b"))

// A DANGLING dep is collected, not fatal — a description of a graph that dies
// on the first typo is useless.
#let dangling = g(row("a", deps: ("nope",)))
#assert.eq(dangling.edges, ())
#assert.eq(dangling.unresolved, (("a", "nope"),))

// ---- find-cycle ------------------------------------------------------------
#assert.eq(find-cycle(simple), ())
// A three-node chain is still acyclic.
#assert.eq(find-cycle(g(row("a"), row("b", deps: ("a",)), row("c", deps: ("b",)))), ())
// A diamond is acyclic too — this is the case a naive visited-set walk calls a
// cycle, which is why the walk colours grey/black rather than just "seen".
#assert.eq(
  find-cycle(g(
    row("a"),
    row("b", deps: ("a",)),
    row("c", deps: ("a",)),
    row("d", deps: ("b", "c")),
  )),
  (),
)
// A two-node loop, and the path names the actual loop.
#let two = find-cycle(g(row("c", deps: ("d",)), row("d", deps: ("c",))))
#assert(two.len() == 3, message: "expected a 3-element cycle path, got " + repr(two))
#assert.eq(two.first(), two.last())
// A self-dependency is a cycle.
#assert.eq(find-cycle(g(row("s", deps: ("s",)))), ("s", "s"))

// ---- is-blocked / blockers-of ---------------------------------------------
#let chain = g(row("a"), row("b", deps: ("a",)))
#assert.eq(is-blocked(chain.nodes.at("b"), chain), true)
#assert.eq(is-blocked(chain.nodes.at("a"), chain), false)
#assert.eq(blockers-of(chain.nodes.at("b"), chain), ("a",))

// Closing the dependency unblocks the dependent.
#let settled = g(row("a", closed: true), row("b", deps: ("a",)))
#assert.eq(is-blocked(settled.nodes.at("b"), settled), false)
#assert.eq(blockers-of(settled.nodes.at("b"), settled), ())

// An UNRESOLVED dep does not block: it names nothing, so it can never close,
// and treating it as a blocker would wedge a todo forever on a typo.
#let ghost = g(row("a", deps: ("nope",)))
#assert.eq(is-blocked(ghost.nodes.at("a"), ghost), false)

// ---- is-ready --------------------------------------------------------------
#let NOW = d(2026, 8, 25)
#assert.eq(is-ready(chain.nodes.at("a"), chain, today: NOW), true)
#assert.eq(is-ready(chain.nodes.at("b"), chain, today: NOW), false)
#assert.eq(is-ready(settled.nodes.at("b"), settled, today: NOW), true)
// A closed todo is never ready.
#assert.eq(is-ready(settled.nodes.at("a"), settled, today: NOW), false)

// Deferral is what makes this br's `ready` and not merely "not blocked".
// Built through `entries(..)` rather than by hardcoding `the `scheduled` log stage`, which is
// what this fixture used to do — and exactly the drift the exported stage names
// exist to prevent. As of 0.6.0 there is no such key: it is a stage in the log.
#let deferred = g(row("x", tags: entries(scheduled: d(2026, 12, 1))))
#assert.eq(is-ready(deferred.nodes.at("x"), deferred, today: NOW), false)
#let arrived = g(row("x", tags: entries(scheduled: d(2026, 8, 1))))
#assert.eq(is-ready(arrived.nodes.at("x"), arrived, today: NOW), true)
// No schedule at all is not deferral — absence of a plan is not a plan to wait.
#assert.eq(is-ready(g(row("x")).nodes.at("x"), g(row("x")), today: NOW), true)

// ---- epic-of ---------------------------------------------------------------
#assert.eq(epic-of((todo: none, "epic-launch": none)), "launch")
#assert.eq(epic-of(todo-tags()), none)
#assert.eq(epic-of((todo: none, "epic-q3-push": none)), "q3-push")

// ---- graph-slice — what a view draws, closed included or not --------------
//
// The pure half of `#todo-graph-view(closed: ..)`, split out so the option is
// testable without a DOM or a rookery registry.

#let g-slice = todo-graph(rows: (
  row("done", closed: true),
  row("open-a", deps: ("done",)),
  row("open-b", deps: ("open-a",)),
))

// `closed: true` is the default and changes nothing: every row, every edge.
#assert.eq(graph-slice(g-slice).rows.len(), 3)
#assert.eq(graph-slice(g-slice).edges.len(), 2)
#assert.eq(graph-slice(g-slice, closed: true).edges, g-slice.edges)

// `closed: false` drops the closed row.
#assert.eq(graph-slice(g-slice, closed: false).rows.map(r => r.name), ("open-a", "open-b"))

// ...and with it, the edge POINTING AT it — a satisfied dependency whose box is
// no longer on the page — while the edge between two open rows survives.
#assert.eq(graph-slice(g-slice, closed: false).edges, (("open-b", "open-a"),))

// ---- ACTIVATED-STAGE — this package's own log vocabulary ------------------
// rookery-timeline reserves `scheduled`, `deadline` and `closed` and leaves the rest
// to its consumers; a status TRANSITION is this package's to name, which its own
// header says outright.
#assert.eq(ACTIVATED-STAGE, "activated")
// The flat status key and the log entry are not redundant: the key is what a tag
// query filters on, the entry is what says since when.
#assert.eq(
  status-of(todo-tags(status: "in-progress")),
  "in-progress",
)

// ---- updated-of over a todo's log — what todos-stale now reads ------------
// It used to read core's `updated`, which fell back to the DOCUMENT's date, so
// staleness measured document age on any project that did not hand-write one.
#assert.eq(
  updated-of((created: d(2026, 1, 1)), entries(timeline: (activated: d(2026, 7, 1)))),
  d(2026, 7, 1),
)
#assert.eq(updated-of((created: d(2026, 1, 1)), (:)), d(2026, 1, 1))

// ---- TODO-LADDER — rookery-timeline's derivations, over this vocabulary --------
// The point of "a structure over the log": nothing here reimplements settledness.
// The ladder is the words, and that package does the reasoning.
#let _T = d(2026, 9, 1)
#assert.eq(TODO-LADDER.terminal, ("closed",))
#assert.eq(TODO-LADDER.transit, ("scheduled", "activated"))
#assert.eq(
  is-settled(entries(timeline: (closed: d(2026, 8, 1))), ladder: TODO-LADDER, today: _T),
  true,
)
#assert.eq(
  is-settled(entries(timeline: (activated: d(2026, 8, 1))), ladder: TODO-LADDER, today: _T),
  false,
)
#assert.eq(
  next-stage(entries(timeline: (scheduled: d(2026, 8, 1))), ladder: TODO-LADDER, today: _T),
  "activated",
)
// `deadline` is deliberately NOT a rung, so a todo carrying one has not advanced.
#assert.eq(rung(entries(deadline: d(2026, 8, 1)), ladder: TODO-LADDER, today: _T), none)

// ---- layer-of / layers — the compile-time twin of `src/layout.js` ---------

// a: no deps. b, c: both depend on a. d: depends on both b and c. The
// horizontal case: b and c share a layer.
#let dag = g(row("a"), row("b", deps: ("a",)), row("c", deps: ("a",)), row("d", deps: ("b", "c")))
#assert.eq(layer-of(dag), (a: 0, b: 1, c: 1, d: 2))
#assert.eq(layers(dag), ((dag.nodes.at("a"),), (dag.nodes.at("b"), dag.nodes.at("c")), (dag.nodes.at("d"),)))

// LONGEST path, not shortest: `e` depends on both `a` and `b`, so it sits one
// layer below `b`, not level with it.
#let longest = g(row("a"), row("b", deps: ("a",)), row("e", deps: ("a", "b")))
#assert.eq(layer-of(longest).at("e"), 2)

// A dangling dep gets a layer anyway — `nope` contributes nothing, so `a`
// stays at layer 0 — and it is `dangling.unresolved`, asserted above, that
// records the dep itself.
#assert.eq(layer-of(dangling).at("a"), 0)

// Within a layer: priority ascending, then name, unprioritised last.
#let rowp(name, deps: (), priority: none) = (
  name: name, deps: deps, closed: false, tags-dict: (:), priority: priority,
)
#let tied = g(rowp("lo", priority: 3), rowp("hi", priority: 1), rowp("none-pri"))
#assert.eq(layers(tied).at(0).map(r => r.name), ("hi", "lo", "none-pri"))

// ---- dfs-of — the deck's reading order ------------------------------------

// A branch is followed to its end before the next one starts, and the todos
// one parent releases are emitted adjacently as a single group.
#let walk = dfs-of(dag)
#assert.eq(walk.order, (a: 0, b: 1, c: 2, d: 3))
#assert.eq(walk.group.at("b"), walk.group.at("c"))
#assert.ne(walk.group.at("a"), walk.group.at("b"))

// `d` depends on both `b` and `c`, and is emitted ONCE — under `b`, the first
// of the two to expand.
#assert.eq(walk.order.len(), 4)

// Depth-first and not layer by layer: `a`'s whole branch lands before the next
// dependency-free todo, even though `z` shares `a`'s layer.
#let two-roots = g(row("a"), row("z"), row("a2", deps: ("a",)))
#assert.eq(dfs-of(two-roots).order, (a: 0, a2: 1, z: 2))

// `roots-together` is the only thing the two deck directions disagree about:
// the dependency-free todos become one group, and are emitted before anything
// they release.
#let together = dfs-of(two-roots, roots-together: true)
#assert.eq(together.order, (a: 0, z: 1, a2: 2))
#assert.eq(together.group.at("a"), together.group.at("z"))

// A dangling dep names nothing that could hold a todo back, so `a` is a root
// here exactly as it is layer 0 above.
#assert.eq(dfs-of(dangling).order.at("a"), 0)

// Sibling lists carry `layers`' own tie-break: priority ascending, then name,
// unprioritised last.
#assert.eq(dfs-of(tied).order, (hi: 0, lo: 1, "none-pri": 2))

// ---- todo-slip-keys — the @rookery/slipshow key functions -----------------
//
// Each of the four functions reads only `r.name` off the row `#slipshow`
// would hand it, so a bare `(name: ..)` dict stands in for an
// `ideas(values: true)` registry row here.
#let reg(name) = (name: name)

// A chain has no sibling group anywhere in it: every slip is a group of one,
// and a group of one gets no row, so the whole deck stacks. `(dk.row)(..)`,
// not `dk.row(..)`: Typst refuses to call a dictionary value with method
// syntax, since a stored key could collide with a built-in method name.
#let sk-chain = g(row("a"), row("b", deps: ("a",)))
#let dk = todo-slip-keys(sk-chain)
#assert.eq((dk.row)(reg("a")), none)
#assert.eq((dk.row)(reg("b")), none)

// Two todos released by the same parent share a row, which is the one thing
// that spans horizontally whatever the direction.
#let dkf = todo-slip-keys(g(row("a"), row("b", deps: ("a",)), row("c", deps: ("a",))))
#assert.eq((dkf.row)(reg("a")), none)
#assert.ne((dkf.row)(reg("b")), none)
#assert.eq((dkf.row)(reg("b")), (dkf.row)(reg("c")))

// `direction:` decides only what the dependency-free todos do: stack by
// default, span one row under `"across"`.
#let sk-roots = g(row("a"), row("b"))
#let dkd = todo-slip-keys(sk-roots)
#assert.eq((dkd.row)(reg("a")), none)
#assert.eq((dkd.row)(reg("b")), none)
#let dka = todo-slip-keys(sk-roots, direction: "across")
#assert.ne((dka.row)(reg("a")), none)
#assert.eq((dka.row)(reg("a")), (dka.row)(reg("b")))

// The zero-padded order key sorts correctly across an eleven-slip deck — a
// plain `str(position)` would put "10" before "2".
#let names10 = range(11).map(i => "n" + str(i))
#let chain10 = g(..names10.enumerate().map(((i, n)) => if i == 0 {
  rowp(n)
} else {
  rowp(n, deps: (names10.at(i - 1),))
}))
#let dk10 = todo-slip-keys(chain10)
#assert.eq(names10.sorted(key: n => (dk10.order)(reg(n))), names10)

// Among siblings, an unprioritised todo sorts after a p3 one.
#let samelayer = g(rowp("p3", priority: 3), rowp("none-pri"))
#let dks = todo-slip-keys(samelayer)
#assert.eq(
  ("p3", "none-pri").sorted(key: n => (dks.order)(reg(n))),
  ("p3", "none-pri"),
)

// The three class strings, and the real fourth case — an open, unblocked
// todo deferred past `today` — which gets no class at all.
#let TODAY = d(2026, 9, 1)
#let classes = g(
  row("done", closed: true),
  row("open-dep"),
  row("blocked", deps: ("open-dep",)),
  row("ready"),
  row("deferred", tags: entries(scheduled: d(2026, 12, 1))),
)
#let dkc = todo-slip-keys(classes, today: TODAY)
#assert.eq((dkc.class)(reg("done")), "todo-slip-closed")
#assert.eq((dkc.class)(reg("blocked")), "todo-slip-blocked")
#assert.eq((dkc.class)(reg("ready")), "todo-slip-ready")
#assert.eq((dkc.class)(reg("deferred")), none)

// `edges` — the todos a slide's own rail is fed FROM, and `blockers-of`'s
// two silences are what make it right. Every case below is over one graph:
// `open-dep` and `other-dep` are open, `shut` is closed, `nowhere` names
// nothing.
#let edg = g(
  row("open-dep"),
  row("other-dep"),
  row("shut", closed: true),
  row("waiting", deps: ("open-dep",)),
  row("satisfied", deps: ("shut",)),
  row("dangling", deps: ("nowhere",)),
  row("two-deps", deps: ("other-dep", "open-dep")),
)
#let dke = todo-slip-keys(edg)
#assert.eq((dke.edges)(reg("waiting")), ("open-dep",))

// A CLOSED dep draws no curve: it would point at a greyed-out slide and say
// something is waiting on work that is done.
#assert.eq((dke.edges)(reg("satisfied")), ())

// A DANGLING dep draws none either — it names nothing that could ever close,
// the same reason `is-blocked` does not let one block a todo.
#assert.eq((dke.edges)(reg("dangling")), ())

// Two open deps come back in `deps` order, not sorted.
#assert.eq((dke.edges)(reg("two-deps")), ("other-dep", "open-dep"))

// A registry row absent from `graph.nodes` — a slip that is not a todo —
// gets `none` from all four functions.
//
// `none` VERSUS `()` IS A REAL DISTINCTION for `edges` and the two lines
// below pin it: `none` means "this slide is not a todo, compute no edges for
// it", `()` means "this todo is blocked by nothing". `#slipshow` drops an
// empty array to no attribute at all, so the two render alike today — but
// they are different claims and either side could come to tell them apart.
#assert.eq((dkc.row)(reg("ghost")), none)
#assert.eq((dkc.order)(reg("ghost")), none)
#assert.eq((dkc.class)(reg("ghost")), none)
#assert.eq((dke.edges)(reg("ghost")), none)
#assert.eq((dke.edges)(reg("open-dep")), ())
