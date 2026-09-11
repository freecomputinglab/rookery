---
id: rk-move-todo-graph-view-into-views-typ-7d46fa97
short-id: 7d
title: Move todo-graph-view into views.typ
priority: 2
labels:
- chore-todos-review
deps:
- blocked-by:rk-destructure-edge-and-pair-tuples-0ae3f2d6
closed: false
---
Move `#todo-graph-view` out of
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/graph.typ` into
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ`.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/graph.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ

## The defect

`graph.typ`'s own file header (lines 1-5) says:

```
// The corpus, the dependency graph over it, and the checks that keep it a DAG.
//
// Nothing here renders. `views.typ` is the rendering half; this file is the
// data and the validation, so a project can build its own views on the same
// footing the shipped ones stand on.
```

But `#todo-graph-view` — currently the last function in this file, from the
comment `// ---- #todo-graph-view — the DAG, as a page element` through the
end of the file (the file is exactly 568 lines long and this function's
closing `}` is its last line) — is entirely rendering code: it builds
`html.elem` markup, an SVG-payload `<script type="application/json">` tag,
and a paged/PDF fallback view. That is exactly the kind of code the header
says lives in `views.typ` instead, where every other `#todos-*` view
(`todos-list`, `todos-ready`, `todos-blocked`, `todos-stale`, `todos-stats`)
already lives. This is the same class of defect the sibling `core` package's
review already found and filed against `core`'s `data.typ` (a module
holding something its own header says it does not).

## Steps

1. In `graph.typ`, cut the entire block from the comment line
   `// ---- #todo-graph-view — the DAG, as a page element` (search for this
   exact string if the line number has drifted; it is currently line 435)
   through the end of the file (currently line 568).

2. Paste that block, unchanged, onto the end of `views.typ` — after the
   `todos-stats` function (currently the file's last function, ending
   around line 372). Leave one blank line between `todos-stats`'s closing
   `}` and the pasted comment.

3. Confirm every name `todo-graph-view` uses is already in scope in
   `views.typ` — it is, and no new import line is needed:
   - `todo-graph`, `assert-acyclic`, `graph-slice`, `is-blocked`, `is-ready`
     all come from `graph.typ`, which `views.typ` already imports in full
     at its own line 25: `#import "graph.typ": *`.
   - `_is-markup` comes from `target.typ`, already imported at `views.typ`
     line 22: `#import "target.typ": *`.
   - `html`, `json`, `context` etc. are Typst built-ins, available
     everywhere.

4. Nothing else in the package needs to change. `lib.typ` imports both
   `graph.typ` and `views.typ` with `*` (lines 22-23:
   `#import "graph.typ": *` then `#import "views.typ": *`), so
   `#todo-graph-view` is re-exported from the package root either way — this
   is a purely internal move with no effect on `#import "@rookery/todos:0.1.0": ...`
   call sites, including the two in
   `/home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/content/index.typ`
   (lines 263 and 270).

5. `graph.typ`'s header (lines 1-5, quoted above) needs no rewording after
   this move — "Nothing here renders" is already exactly what it says; the
   move is what makes the sentence true rather than aspirational.

## Do NOT

- Do not change `todo-graph-view`'s behavior, parameters, or rendered
  output in any way — this is a pure relocation.
- Do not move any other function. `graph-slice` in particular stays in
  `graph.typ`: it is a pure data function (explicitly documented at its own
  comment, around line 256-259, as existing so "a project building its own
  view stands on the same footing this file's header claims to offer") and
  the header's claim already covers it correctly.
- Do not touch `test/units.typ` — it tests `graph-slice` directly (see its
  comment "The pure half of `#todo-graph-view(closed: ..)`", around line
  235) and does not call `todo-graph-view` itself, so nothing there needs
  updating.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test-js
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

All three must stay green exactly as before. `just check`'s
`rheo compile demo/rheo` step compiles
`demo/rheo/content/index.typ`, which calls `#todo-graph-view` twice (lines
263 and 270) — a broken import or a missed dependency after the move would
fail that compile with an "unknown variable" error rather than silently
changing output.