---
id: rk-destructure-edge-and-pair-tuples-0ae3f2d6
short-id: 0a
title: Destructure edge and pair tuples
priority: 2
labels:
- chore-todos-review
deps:
- blocked-by:rk-resolve-todos-once-per-view-92dd0465
- blocked-by:rk-index-shown-names-as-a-set-22a2b00d
closed: false
---
Destructure edge and pair tuples instead of reading them with `.at(0)`/`.at(1)`, in
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/graph.typ` and
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ`.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/graph.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ

## The inconsistency

This package represents a graph edge as a 2-element array `(from, to)`
(see `graph.typ`'s own doc comment on `todo-graph`, around line 59: "an edge
runs FROM a todo TO something it depends on") and a stats row as a
2-element array `(key, value)`, then reads several of them back with
`.at(0)`/`.at(1)` instead of destructuring the pair in the closure
parameter or `for` loop — even though Typst's destructuring syntax
(`for (a, b) in ..`, `.map(((a, b)) => ..)`) is already used elsewhere in
this very file, e.g. `graph.typ`'s `find-cycle`, around line 113:
`let (node, i) = stack.last()`. Both spellings exist side by side, which is
the inconsistency this bird removes.

NOTE ON LINE NUMBERS: this bird is blocked-by two other birds that also
touch `graph.typ` and `views.typ` (a performance fix reordering the tops of
several functions, and one reindexing a variable inside
`#todo-graph-view`). Those land first, so by the time this bird is worked
the line numbers below may have drifted by a line or two. Locate each site
by the surrounding function name and code shown, not by the line number
alone.

## Sites in `graph.typ`

1. Inside `find-cycle` (around line 102):
   ```
   for e in graph.edges { adj.insert(e.at(0), adj.at(e.at(0)) + (e.at(1),)) }
   ```
   becomes:
   ```
   for (from, to) in graph.edges { adj.insert(from, adj.at(from) + (to,)) }
   ```

2. Inside `find-cycle`, a few lines later (around line 126):
   ```
   let path = stack.map(f => f.at(0))
   ```
   `f` here is a `(node, i)` pair (the same shape already destructured a few
   lines above as `let (node, i) = stack.last()`), so change to:
   ```
   let path = stack.map(((node, _)) => node)
   ```

3. Inside `todos-validate` (around line 239):
   ```
   graph.unresolved.map(p => p.at(0) + " -> " + p.at(1)).join(", ")
   ```
   `graph.unresolved` pairs are `(from, dep)` per `todo-graph`'s own doc
   comment (line 58: `unresolved: ((from, dep), ..)`), so change to:
   ```
   graph.unresolved.map(((from, dep)) => from + " -> " + dep).join(", ")
   ```

4. Inside `graph-slice` (around line 266):
   ```
   edges: graph.edges.filter(e => e.at(0) in open-names and e.at(1) in open-names),
   ```
   becomes:
   ```
   edges: graph.edges.filter(((from, to)) => from in open-names and to in open-names),
   ```

5. Inside `layer-of` (around line 301):
   ```
   for e in graph.edges { deps.insert(e.at(0), deps.at(e.at(0)) + (e.at(1),)) }
   ```
   becomes:
   ```
   for (from, to) in graph.edges { deps.insert(from, deps.at(from) + (to,)) }
   ```

6. Inside `dfs-of` (around lines 381-382):
   ```
   for e in graph.edges {
     kids.insert(e.at(1), kids.at(e.at(1)) + (e.at(0),))
     has-dep.insert(e.at(0), true)
   }
   ```
   becomes:
   ```
   for (from, to) in graph.edges {
     kids.insert(to, kids.at(to) + (from,))
     has-dep.insert(from, true)
   }
   ```

7. Inside `todo-graph-view` (around lines 521-522):
   ```
   edges: edges.map(e => (from: e.at(0), to: e.at(1))),
   unresolved: graph.unresolved.map(e => (from: e.at(0), to: e.at(1))),
   ```
   becomes:
   ```
   edges: edges.map(((from, to)) => (from: from, to: to)),
   unresolved: graph.unresolved.map(((from, dep)) => (from: from, to: dep)),
   ```
   (`edges` uses `from`/`to` per `todo-graph`'s doc comment; `unresolved`
   uses `from`/`dep` per the same doc comment's `(from, dep)` naming for
   that array specifically.)

## Sites in `views.typ`

`todos-stats` builds an array of `(key, value)` pairs named `pairs` (around
lines 328-341: `let pairs = ( ("total", rows.len()), ... )`, then
`pairs.push((...))` a few times) and reads them back in two places:

8. The paged branch (around line 347):
   ```
   pairs.map(pr => text(gray, pr.at(0)) + " " + str(pr.at(1))).join(", ")
   ```
   becomes:
   ```
   pairs.map(((key, value)) => text(gray, key) + " " + str(value)).join(", ")
   ```

9. The HTML branch (around line 368):
   ```
   pairs.map(pr => cell(pr.at(0), pr.at(1))).join(),
   ```
   becomes:
   ```
   pairs.map(((key, value)) => cell(key, value)).join(),
   ```

## Do NOT

- Do not touch `skin.typ`'s `pos.at(0)` (line 57 there) — `pos` is
  `args.pos()`, an arbitrary-length positional-argument array, not a
  2-element pair, so destructuring does not apply and this site is out of
  scope.
- Do not touch `graph.typ`'s existing `let (node, i) = stack.last()` — it is
  already destructured correctly.
- Do not change behavior anywhere — every site above is a pure rewrite of
  how an existing pair is read, not what is computed from it.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test-js
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

All three must stay green exactly as before — these are pure refactors with
no behavior change, so a mistake (e.g. swapping `from`/`to`) would either
fail to compile (wrong destructuring arity) or change a test assertion in
`just test` (which exercises `find-cycle`, `layer-of`, `dfs-of`, and
`todos-stats` directly).