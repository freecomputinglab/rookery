---
id: rk-rename-filter-panel-to-todo-table-9971e639
title: 'Rename #filter-panel to #todo-table'
priority: 3
labels:
- today-panel
- type:task
deps:
- blocked-by:rookery-priority-sort-3ta
- blocked-by:rookery-priority-rung-47g
closed: false
---
`@rookery/todos` calls its main view `#filter-panel`, and the name is wrong twice over.

It is wrong about the thing: filtering is the least of what it does. It projects todo rows into a table — the `state`/`epic`/`tag`/`priority` facets derived from the dependency graph, the countdown wash on the date cell, the undated row's priority label, the pill layout — and the filter box is one piece of chrome on top of that.

And it is wrong about the namespace: `@rookery/search` has its OWN `#filter-panel`, a different function with a different signature, and this one shadows it. The shadowing is deliberate and documented, but it means the one consuming site cannot reach the unskinned version without an alias import — `/home/lox/code/waterline/rookery/_lib/rookery.typ:65` imports it as `idea-filter-panel` for exactly this reason, with nine lines of comment explaining the workaround.

Rename it to `#todo-table`. Both problems go at once: the name says what the thing is, and `@rookery/search`'s `#filter-panel` stops being shadowed at all.

NO BACKWARD COMPATIBILITY. `/home/lox/code/waterline` is this package's only consumer, and switching it over is a separate bird in that repository. Do not leave an alias, a deprecation shim, or a re-export under the old name.

All paths in the steps below are under `/home/lox/code/_fcl/rookery/` unless written out in full.

## THE TRAP: two packages have a `#filter-panel`

`rg filter-panel` across this monorepo returns both. Only `@rookery/todos`' is being renamed. `@rookery/search`'s own `#filter-panel` — defined in `search/0.1.0/src/filter-panel.typ`, documented across `search/0.1.0/readme.md`, demoed in `search/0.1.0/demo/` — KEEPS ITS NAME AND IS NOT TOUCHED BY THIS BIRD. Before changing any line that mentions `filter-panel`, decide which of the two it means. The rule of thumb: a mention inside `search/0.1.0/**` is search's; a mention that says "@rookery/todos'" or sits in `todos/0.1.0/**` is this one; anything else, read the sentence.

## Steps

1. **Rename the file.** `todos/0.1.0/src/panel.typ` becomes `todos/0.1.0/src/table.typ`. The module's name should match the function it exists for.

2. **Rename the function.** In the newly-named `src/table.typ`, `#let filter-panel(` (currently line 146) becomes `#let todo-table(`. Nothing about its parameter list changes except the addition in step 3.

3. **Add one parameter, `corpus: none`**, immediately after `rows:` in the parameter list. It is the set of todos the DEPENDENCY GRAPH is built from, where `rows:` is the set that gets listed. Default `none` means "the same as `rows:`", which is what the function does today.

   The body change is one line. `let graph = todo-graph(rows: all)` (currently line 284) becomes:

   ```
   let graph = todo-graph(rows: if corpus != none { corpus } else { all })
   ```

   Document it with the reason, which is already stated in the comment at lines 280-283 and must be kept and extended: the graph has to see EVERY todo, because a listed todo's blocker is very often closed, and a blocker missing from the graph reads to `is-blocked` as "not blocking" — quietly promoting a blocked todo to ready. A caller passing a pre-narrowed `rows:` therefore has to pass the whole corpus too, or every row it lists comes out `ready`.

4. **Rewrite the file header** (currently lines 1-38). Its argument inverts. Today it says the skin pattern is applied sideways, that the name is the point, and that "a call site keeps writing `#filter-panel(..)`" while the pills quietly become grouped and derived. None of that is true after this bird: the name is now this package's own and shadows nothing. What the new header says, in this repo's comment style — present tense, describing what the file is, one header and no interior banners, no issue ids (see `/home/lox/code/_fcl/rookery/CLAUDE.md`):

   - what `#todo-table` is: todo rows projected into `@rookery/search`'s `#panel`, with the facets that only this package can derive (`ready` and `blocked` come from `graph.typ` and nowhere else, which is why a panel that cannot press them is the one thing every consuming site ends up hand-rolling).
   - that it delegates to `#panel` rather than to `@rookery/search`'s `#filter-panel`, and why: `#panel`'s facet mode composes per group, so epic, tag, state and priority each become their own group, where `#filter-panel` has one pill row and one `pill-match` for all of it.
   - KEEP the existing paragraphs about `union:` (the subject groups OR where state and priority AND) and about `multi:` and the `tag` group — those are still exactly right and are the file's most useful comments.
   - DROP the paragraphs about shadowing and about the name being the point. There is no shadowing any more.

5. **Update the in-package references.** Each of these names the todos view and must read `#todo-table`:
   - `todos/0.1.0/src/lib.typ:27` — the comment saying `#filter-panel` is the one name sourced from @rookery/search. Also change the `#import "panel.typ": *` on line 29 to `#import "table.typ": *`, keeping its position: the import order in that file is dependency order and is load-bearing, and `skin.typ` must stay LAST.
   - `todos/0.1.0/src/search.typ:35` — the banner explaining which half of "this package must never grow an edge to @rookery/search" still holds.
   - `todos/0.1.0/src/todos.css:243` — the comment naming the row whose date cell carries the band.
   - `todos/0.1.0/demo/rheo/content/index.typ` — the import list at line 7, the prose at line 91, the section heading at line 198, and the call at line 219.
   - `todos/0.1.0/demo/rheo/check.sh:103` and `:197` — a comment and a progress string.
   - `todos/0.1.0/readme.md` — the whole documented section at lines 333-453, plus every other mention of the name in that file. Also document the new `corpus:` argument there, beside `rows:`.
   - `/home/lox/code/_fcl/rookery/CLAUDE.md:26` — the sentence about skinning `#filter-panel` into a version whose pills know the todo graph.

6. **Update the cross-package references in `@rookery/timeline`**, all of which say "@rookery/todos' `#filter-panel`" and are now wrong: `timeline/0.1.0/src/upcoming.typ:106`, `:183`, `:277`; `timeline/0.1.0/src/when.typ:162`; `timeline/0.1.0/src/timeline.css:45`; `timeline/0.1.0/test/units.typ:481`; `timeline/0.1.0/readme.md:833`. Note that `upcoming.typ:183` contains the worked call `#filter-panel(rows: upcoming-rows(..), when: r => r.when)`, which becomes `#todo-table(..)`.

   LEAVE `timeline/0.1.0/readme.md:747-749` ALONE. That example imports from `@rookery/search` and is about search's own panel.

7. **Check `core/0.1.0/src/row.typ:43`** — "`#filter-panel` builds .." in a comment about who owns the list item. Read the sentence and decide which package it means; if it means both, say both. Change it only if it means the todos one.

## Do NOT

- Do not touch anything under `search/0.1.0/`. Every `filter-panel` in there is search's own.
- Do not leave an alias, a deprecation warning, or a re-export under the old name anywhere.
- Do not change any behaviour: no default value, no other parameter, no rendered markup, no CSS class, no assertion logic. The one behavioural addition is `corpus:`, and with its default the function does exactly what it did.
- Do not change `/home/lox/code/waterline`. That repo's switch-over is its own bird, and this package has no business editing its consumer.
- Do not rename `#todos-search`, `#todos-list`, or any other view. This bird renames one function.

## VERIFY

From `/home/lox/code/_fcl/rookery/todos/0.1.0`:

1. Before editing, capture the current output: `rheo compile demo/rheo && cp demo/rheo/build/html/index.html /tmp/todo-table-before.html`.
2. `just test` passes.
3. `just check` passes — it runs `just build`, `rheo compile demo/rheo`, then `./demo/rheo/check.sh`.
4. `rg -n 'filter-panel' /home/lox/code/_fcl/rookery/todos /home/lox/code/_fcl/rookery/timeline /home/lox/code/_fcl/rookery/CLAUDE.md` returns only `timeline/0.1.0/readme.md:747` and `:749`, which are `@rookery/search`'s panel and are correct as they stand.
5. `rg -n 'todo-table' todos/0.1.0/src/` shows the function defined once, in `table.typ`.
6. `diff /tmp/todo-table-before.html demo/rheo/build/html/index.html` shows ONLY prose and heading changes — the section title and the sentences naming the view. No `class=`, no `data-`, and no `<li>` differs. A structural difference means something other than a rename happened.
