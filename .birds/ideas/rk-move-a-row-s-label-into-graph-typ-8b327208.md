---
id: rk-move-a-row-s-label-into-graph-typ-8b327208
short-id: 8b
title: Move a row's label into graph.typ
priority: 2
labels:
- feat-todo-blocked-by-header
deps: []
closed: false
---
Touches: todos/0.1.0/src/graph.typ, todos/0.1.0/src/views.typ

Move the `_label(row)` helper out of `views.typ` and into `graph.typ`. This is a
pure move: no behaviour changes, no rename, no change to what the helper
returns. Everything in this bird happens inside `todos/0.1.0/`.

## Why the move is needed

`_label(row)` turns one `todos()` row into its display text — its title, or its
name in `raw()` when it has no title. It currently lives in `views.typ`, and
`search.typ` already reaches it from there.

A companion bird adds a renderer that also needs a row's label, and that
renderer has to live in a file `todo.typ` imports. `views.typ` imports
`todo.typ` (`#import "todo.typ": *`, `views.typ:24`), so a file that imports
`views.typ` and is imported by `todo.typ` closes an import cycle, which Typst
refuses outright. The label rule is a property of a row, and `graph.typ` is
where rows are built — so that is where it belongs, and from there every file in
the package can reach it without a cycle.

## Steps

1. Find the definition and the comment above it:

   ```sh
   rg -n -F "// A row's label: its title, or its name when untitled." /home/lox/code/_fcl/rookery/todos/0.1.0/src
   ```

   One hit as of filing, `src/views.typ:35`, immediately above

   ```typ
   #let _label(row) = if row.title == none { raw(row.name) } else { row.title }
   ```

   at `src/views.typ:36`. If the anchor misses, widen the search to
   `/home/lox/code/_fcl/rookery/todos/0.1.0`; if it still misses, stop and
   report the miss rather than writing a fresh helper.

2. Delete both of those lines — the comment and the `#let` — from
   `src/views.typ`. Leave the blank lines around the hole tidy: one blank line
   between the neighbouring blocks, not two.

3. Paste both lines, unchanged, into `src/graph.typ`, immediately above this
   line:

   ```sh
   rg -n -F '// ---- cycle detection' /home/lox/code/_fcl/rookery/todos/0.1.0/src/graph.typ
   ```

   One hit as of filing, `src/graph.typ:86`. Put a blank line between the pasted
   `#let` and that divider comment so the new helper reads as part of the
   preceding row-and-graph material rather than as part of cycle detection.

4. Change nothing else. `views.typ` already carries
   `#import "graph.typ": *` (`views.typ:25`, one hit) and `search.typ` already
   carries the same import (`search.typ:50`), so both keep resolving `_label`
   with no edit. Confirm that import line is still present in `views.typ` rather
   than adding a second one.

## Non-goals

- Do NOT rename the helper or drop its leading underscore. Three files call it
  by that exact name.
- Do NOT change what it returns, or add parameters to it.
- Do NOT edit `search.typ`, `table.typ`, `lib.typ`, `todo.typ`, `todos.css` or
  `readme.md`. `lib.typ` re-exports `graph.typ` with `*` already, so the move
  needs no export change.
- Do NOT add the companion bird's renderer here. This bird moves one helper and
  stops.
- Do NOT reflow, reword or "improve" the moved comment. It is correct as it
  stands.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/todos/0.1.0`.

1. The helper is in its new home and gone from its old one:

   ```sh
   rg -c -F '#let _label(row)' src/graph.typ   # prints 1
   rg -c -F '#let _label(row)' src/views.typ   # prints nothing, exits 1
   ```

2. The Typst fixture still compiles, which is what proves every caller still
   resolves the name:

   ```sh
   just test
   ```

   Ends with `units OK` and exits 0.

3. The demo project still builds and its output assertions still pass:

   ```sh
   just check
   ```

   Ends with `demo/rheo OK`. Note that `just check` runs `just build` first,
   which runs `pnpm install`; if that step cannot reach the network, run
   `just test` and then `rheo compile demo/rheo` followed by
   `./demo/rheo/check.sh` directly, and say in your report that `pnpm install`
   was skipped.