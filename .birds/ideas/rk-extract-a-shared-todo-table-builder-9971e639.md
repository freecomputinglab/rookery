---
id: rk-extract-a-shared-todo-table-builder-9971e639
short-id: '9'
title: Extract a shared todo table builder
priority: 3
labels:
- today-panel
- type:task
deps:
- blocked-by:rookery-priority-sort-3ta
- blocked-by:rookery-priority-rung-47g
closed: false
---
`@rookery/todos`' `#filter-panel` is one 260-line `context` block doing two separable jobs. It SELECTS which todos to list — every open one, narrowed by the caller's `filter:` — and it PROJECTS them into `@rookery/search`'s `#panel` with the todo skin: the `state`/`epic`/`tag`/`priority` facets, the countdown wash on the date cell, the undated row's priority label, the pill layout, and the assertions that guard all of it.

A second panel over a DIFFERENT selection needs the whole of the second job and none of the first, and today there is no way to have it short of copying the file. This bird splits the projection out into a shared builder so a day view can be written as a selection and nothing else.

THIS IS A PURE REFACTOR. Nothing about `#filter-panel`'s surface or output changes, and the VERIFY below is built around exactly that claim: the rendered demo page must come out byte-identical.

All paths are under `/home/lox/code/_fcl/rookery/todos/0.1.0/`.

## The current shape of `src/panel.typ` (530 lines)

- 40-51 — the module imports (`@rookery/search`'s `panel`, `@rookery/core`'s `idea-row-body`, `@rookery/timeline` twice, and this package's `target.typ`, `tags.typ`, `todo.typ`, `graph.typ`)
- 53-66 — `_fmt-day`, `_iso`, `_past`, with their comments
- 82-89 — `_SUBJECT`, `_MULTI`
- 91-144 — `_tags-of`, `_state-of`, with their long comments
- 146-270 — `#filter-panel`'s parameter list and its documentation
- 271 — `) = context {`
- 272-277 — the `order in ("newest", "soonest")` assert
- 279 — `let all = if rows != none { rows } else { todos() }` — SELECTION
- 284 — `let graph = todo-graph(rows: all)`
- 286 — `let keep = if filter != none { filter } else { r => not r.closed }` — SELECTION
- 287-292 — the `when` adapter's default
- 299-312 — `ranked`, the priority pre-sort
- 314-334 — the projection `map`, and the `overdue` drop at 334
- 336-464 — `draw`, the row renderer
- 466-488 — `facet-rows` and the two asserts over it
- 490-529 — the `panel(..)` call

## Steps

1. Create `src/table.typ`. Give it a file header in this repo's own comment style — present tense, describing what the file IS, one header and no interior banners, no issue ids (see `/home/lox/code/_fcl/rookery/CLAUDE.md`). What it says: this is the projection every todo panel shares — a selected set of todo rows becomes `@rookery/search`'s `#panel` with the graph-derived facets and the date-cell ramp — and which rows are selected is the CALLER's question, which is what makes two panels possible over one projection.

2. Move into `src/table.typ`, unchanged and with their comments: the imports at panel.typ:40-51, and `_fmt-day`, `_iso`, `_past`, `_SUBJECT`, `_MULTI`, `_tags-of`, `_state-of` (panel.typ:53-144).

3. In `src/table.typ`, define `_todo-table` with this parameter list:

   ```
   #let _todo-table(
     rows: (),
     corpus: none,
     today: none,
     facets: ("epic", "tag", "state", "priority"),
     tag-filter: none,
     pill-rows: <the same default literal now at panel.typ:204-208>,
     when: none,
     order: "soonest",
     countdown: true,
     overdue: true,
     undated-priority: true,
     visible: 8,
     placeholder: "Filter",
     noun: "todos",
     empty: [Nothing here.],
     haystack: none,
     render: none,
   ) = {
   ```

   Its body is panel.typ lines 272-277 and 284-529 verbatim, with these three edits and no others:

   - `let graph = todo-graph(rows: if corpus != none { corpus } else { rows })`. THE GRAPH MUST BE BUILT FROM EVERY TODO, not from the listed ones. The comment at panel.typ:280-283 says why and moves with the line: a todo's blocker is very often closed, and a closed row dropped before the graph is built leaves the blocker unresolvable, which `is-blocked` reads as "not blocking" — quietly promoting a blocked todo to ready.
   - `ranked` (panel.typ:308-312) sorts `rows` where it currently sorts `all.filter(keep)`. Nothing else in that block changes.
   - the `order` assert's message names a todo panel rather than `#filter-panel`, because two functions reach it now: `"@rookery/todos: a todo panel's ``order`` must be \"newest\" (the most recent date first) or \"soonest\" (the earliest first) — got "`.

   `_todo-table` is a PLAIN function, not a `context` block. `#filter-panel` already opens one, and a nested `context` is a second layout pass buying nothing.

4. In `src/panel.typ`: delete everything steps 2 and 3 moved out, add `#import "table.typ": *` alongside the remaining imports, and reduce the body after `) = context {` to exactly:

   ```
     let all = if rows != none { rows } else { todos() }
     let keep = if filter != none { filter } else { r => not r.closed }
     _todo-table(
       rows: all.filter(keep),
       corpus: all,
       today: today,
       facets: facets,
       tag-filter: tag-filter,
       pill-rows: pill-rows,
       when: when,
       order: order,
       countdown: countdown,
       overdue: overdue,
       undated-priority: undated-priority,
       visible: visible,
       placeholder: placeholder,
       noun: noun,
       empty: empty,
       haystack: haystack,
       render: render,
     )
   ```

   `#filter-panel` keeps its entire parameter list and every line of its documentation exactly where it is. That documentation is the package's public surface and this bird does not touch it. `panel.typ` still needs whichever of `todos` / `todo-graph` its remaining two lines use — keep the imports those need and drop the rest.

5. `src/lib.typ` needs NO edit. It star-imports `panel.typ` at line 29, and a Typst module re-exports every top-level binding it holds, imported ones included — so `table.typ`'s names arrive through that. Confirm this by building rather than by adding a line.

## Do NOT

- Do not change any default value, any parameter name, any rendered markup, any CSS class, or one word of `#filter-panel`'s documentation.
- Do not make `_todo-table` public API. The leading underscore is this package's convention for internal (`_state-of`, `_tags-of`, `_past` are all like this) even though a star-import re-exports it anyway.
- Do not add the day-view selection here. That is a separate bird.
- Do not touch `src/todos.css`, `src/views.typ`, `src/graph.typ`, `src/search.typ` or any `.js` file.

## VERIFY

From `/home/lox/code/_fcl/rookery/todos/0.1.0`:

1. Before editing anything, capture the current output: `rheo compile demo/rheo && cp demo/rheo/build/html/index.html /tmp/todo-panel-before.html`.
2. `just test` passes (it runs `typst compile --features html --root . --format pdf test/units.typ /dev/null` and `./test/panics.sh`).
3. `just check` passes (it runs `just build`, then `rheo compile demo/rheo`, then `./demo/rheo/check.sh`).
4. `rheo compile demo/rheo && diff /tmp/todo-panel-before.html demo/rheo/build/html/index.html` prints NOTHING. A refactor that moves a row, changes a class or reorders an attribute has failed this bird, not passed it.
5. `rg -n '_todo-table' src/` shows it defined once in `table.typ` and called once in `panel.typ`.

Note on the package's build: `typst.toml` sets `entrypoint = "src/lib.typ"`, so a `.typ` edit takes effect immediately and `just build` is only needed for the JavaScript bundle in `dist/`. Run `just check` anyway — it is the recipe that builds first and then asserts on the output.