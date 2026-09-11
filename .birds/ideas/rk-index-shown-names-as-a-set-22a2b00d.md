---
id: rk-index-shown-names-as-a-set-22a2b00d
short-id: '22'
title: Index shown-names as a set
priority: 4
labels:
- chore-todos-review
deps: []
closed: false
---
Index `shown-names` as a dictionary instead of an array in
`#todo-graph-view`, in
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/graph.typ`.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/graph.typ

## The defect

`todo-graph-view` (this file, currently lines 455-568) builds `shown-names`
as a plain array at line 478:

```
let shown-names = rows.map(r => r.name)
```

and then tests membership in it inside `shown-deps`, line 479:

```
let shown-deps(r) = r.deps.filter(d => d not in graph.nodes or d in shown-names)
```

`shown-deps` is called once per rendered row — in the paged/non-markup
branch (around line 494, inside `list(..rows.map(r => { ... shown-deps(r) ... }))`)
and again in the HTML fallback branch (around line 553, inside the
`.map(r => { ... shown-deps(r) ... })` that builds `.todo-graph-fallback`
list items).

Typst's `in` on an array is a linear scan, so `d in shown-names` costs
`O(rows.len())` per test, and it runs once per dependency of every rendered
row — roughly `O(total deps across all rows × visible rows)` instead of
`O(total deps)`. This is the same "one pass into a dictionary answers the
same question" shape as `@rookery/search`'s already-fixed `#filter-panel`
defect (pills × rows, each rebuilding a row's tag array) — here it's deps ×
rows instead.

## Fix

Build `shown-names` as a dictionary keyed by name (a dummy value works,
since only key presence is tested) instead of an array, so `in` becomes an
`O(1)` dictionary lookup. This package already uses exactly this idiom
elsewhere — `todo-graph`'s own `nodes` (line 75:
`let nodes = rows.map(t => (t.name, t)).to-dict()`) is a dictionary keyed by
name for the same reason.

## Steps

1. In `graph.typ`, replace the current line
   ```
   let shown-names = rows.map(r => r.name)
   ```
   with
   ```
   let shown-names = rows.map(r => (r.name, true)).to-dict()
   ```
2. Leave the `shown-deps` line immediately below it completely unchanged —
   `d in shown-names` already reads correctly whether `shown-names` is an
   array or a dictionary (Typst's `in` tests key presence on a dictionary
   the same way it tests element presence on an array), so this line's
   *behavior* is identical; only its cost changes.

## Do NOT

- Do not touch `graph-slice` (a different function, earlier in the file) —
  it already builds `open-names` as an array too, but that is a separate,
  smaller instance not covered by this bird; leave it alone.
- Do not change `todo-graph-view`'s rendered output. This is a pure
  performance change: the set of names in `shown-names` and the results of
  every `d in shown-names` test must be identical before and after.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test-js
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

All three must stay green exactly as before. `just check`'s `rheo compile
demo/rheo` step renders `#todo-graph-view` twice (`demo/rheo/content/index.typ`
lines 263 and 270) with a real dependency graph and dangling/closed
dependencies among the demo's todos, so a behavior change here (a
dependency note dropped or wrongly kept) would change that compiled output.