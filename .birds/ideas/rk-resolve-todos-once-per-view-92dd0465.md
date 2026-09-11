---
id: rk-resolve-todos-once-per-view-92dd0465
short-id: 92d
title: Resolve todos() once per view
priority: 4
labels:
- chore-todos-review
deps: []
closed: false
---
Resolve `todos()` once per view, not twice, across six functions in two
files: `/home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ` and
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/search.typ`.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/src/search.typ

## The defect

`todo-graph()` (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/graph.typ`, line 73)
takes an optional `rows:` argument. When called with no argument
(`todo-graph()`), it computes `rows` itself at line 74:
`let rows = if rows == none { todos() } else { rows }`.

`todos()` (same file, lines 30-48) is a full-corpus resolution: it calls
`@rookery/core`'s `ideas()` and `tag-data()`, both of which resolve Typst's
`.final()` — a document-wide operation — and then maps every row through
`priority-of`/`type-of`/`status-of`/etc.

Six call sites call `todo-graph()` with NO `rows:` argument, and then
separately call `todos()` again for their own row list — paying the
document-wide `.final()` resolution TWICE where once would do:

- `/home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ`, `todos-list` (around lines 199-202)
- same file, `todos-ready` (around lines 223-225)
- same file, `todos-blocked` (around lines 242-245)
- same file, `todos-stale` (around lines 278-297)
- same file, `todos-stats` (around lines 321-323)
- `/home/lox/code/_fcl/rookery/todos/0.1.0/src/search.typ`, `todos-search` (around lines 143-157)

`todo-table` in `table.typ` (lines 309-317) already avoids this exact
mistake — do not touch that file, just copy its pattern: it computes
`let all = if rows != none { rows } else { todos() }` FIRST, then calls
`todo-graph(rows: if corpus != none { corpus } else { all })`, so
`todo-graph` never has to call `todos()` itself.

## Steps

1. In `views.typ`, `todos-list` (currently):
   ```
   let graph = todo-graph()
   assert-acyclic(graph)
   let rows = todos()
   ```
   becomes:
   ```
   let rows = todos()
   let graph = todo-graph(rows: rows)
   assert-acyclic(graph)
   ```
   (The rest of the function, which mutates `rows` via `.filter`/`.sorted` etc., is unaffected — it already reassigns the local `rows` binding.)

2. In `views.typ`, `todos-ready` (currently):
   ```
   let graph = todo-graph()
   assert-acyclic(graph)
   let rows = _by-priority(todos().filter(r => is-ready(r, graph, today: today)))
   ```
   becomes:
   ```
   let all = todos()
   let graph = todo-graph(rows: all)
   assert-acyclic(graph)
   let rows = _by-priority(all.filter(r => is-ready(r, graph, today: today)))
   ```

3. In `views.typ`, `todos-blocked` (currently):
   ```
   let graph = todo-graph()
   assert-acyclic(graph)
   let rows = _by-priority(
     todos().filter(r => not r.closed and is-blocked(r, graph)),
   )
   ```
   becomes:
   ```
   let all = todos()
   let graph = todo-graph(rows: all)
   assert-acyclic(graph)
   let rows = _by-priority(
     all.filter(r => not r.closed and is-blocked(r, graph)),
   )
   ```

4. In `views.typ`, `todos-stale` (currently):
   ```
   let graph = todo-graph()
   assert-acyclic(graph)
   assert(
     ...older-than check...
   )
   let stale(u) = ...
   let touched = r => updated-of(r, r.tags-dict)
   let rows = todos().filter(r => { ... })
   ```
   becomes (move the `todos()` call above the `todo-graph()` call, leave the assert and the two `let`s where they are, and filter `all` instead of calling `todos()` again):
   ```
   let all = todos()
   let graph = todo-graph(rows: all)
   assert-acyclic(graph)
   assert(
     ...older-than check, unchanged...
   )
   let stale(u) = ...unchanged...
   let touched = r => updated-of(r, r.tags-dict)
   let rows = all.filter(r => { ...unchanged body... })
   ```

5. In `views.typ`, `todos-stats` (currently):
   ```
   let graph = todo-graph()
   assert-acyclic(graph)
   let rows = todos()
   ```
   becomes:
   ```
   let rows = todos()
   let graph = todo-graph(rows: rows)
   assert-acyclic(graph)
   ```

6. In `search.typ`, `todos-search` (currently):
   ```
   let graph = todo-graph()
   assert-acyclic(graph)
   ...sync assert block, unchanged...
   let rows = todos()
   ```
   becomes:
   ```
   let rows = todos()
   let graph = todo-graph(rows: rows)
   assert-acyclic(graph)
   ...sync assert block, unchanged, still between graph and the rest of the function...
   ```
   (Reorder so `let rows = todos()` moves above `let graph = ...`; the sync-parameter assert block that currently sits between `assert-acyclic(graph)` and `let rows = todos()` can stay in the same relative position, either before or after the graph/rows pair — it does not read `graph` or `rows`.)

7. While editing `views.typ`, also drop three now-confirmed-unused imports at the top of the file (this is unrelated to the `todos()` fix but is a one-line cleanup in the same file, worth doing in the same pass): line 20 currently reads
   ```
   #import "@rookery/core:0.1.0": ideas, window
   ```
   — `ideas` is never called anywhere in this file (confirmed with `grep -c '\bideas(' views.typ` = 0; the only other occurrence of the string "ideas" in the file is inside an unrelated comment about `#ideas-outline`). Change it to:
   ```
   #import "@rookery/core:0.1.0": window
   ```
   Line 21 currently reads
   ```
   #import "@rookery/timeline:0.1.0": entries, deadline-of, is-overdue, scheduled-of, updated-of
   ```
   — `deadline-of` and `scheduled-of` are never called anywhere in this file (`grep -c` for each is 0). Change it to:
   ```
   #import "@rookery/timeline:0.1.0": entries, is-overdue, updated-of
   ```
   Keep `entries`, `is-overdue`, `updated-of`, and `window` — all four ARE used in this file.

## Do NOT

- Do not change `todo-graph`'s own signature or default behavior in `graph.typ`. It must keep working exactly as it does today for every OTHER caller that has no pre-computed rows to hand it — `todo-graph-view`, `todos-validate`, and `todo-slipshow` (in `deck.typ`) all correctly call `todo-graph()` with no `rows:` and do not separately re-fetch `todos()`; leave all three alone.
- Do not touch `table.typ` — it already uses the correct pattern.
- Do not remove `window`, `entries`, `is-overdue`, or `updated-of` from the imports — all four are used.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test-js
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

All three must print the same success they did before this change: `just test` ends with `units OK`; `just test-js` reports all tests passing (`ℹ fail 0`); `just check` ends with `demo/rheo OK`. This is a pure performance change — no test assertion or demo output should differ, because every view still returns the identical rows in the identical order.