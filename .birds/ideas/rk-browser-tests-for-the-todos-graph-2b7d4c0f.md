---
id: rk-browser-tests-for-the-todos-graph-2b7d4c0f
short-id: 2b7d
title: Browser tests for the todos graph
priority: 4
labels:
- test-browser
deps:
- blocked-by:rk-stand-up-the-shared-browser-harness-cbc3ae56
closed: false
---
`@rookery/todos` renders a dependency DAG as SVG, built in the browser from a
JSON payload the Typst side emits. `render` — the function that does all of it —
has no test of any kind.

WHAT IS COVERED TODAY:

- `/home/lox/code/_fcl/rookery/todos/0.1.0/test/layout.test.mjs` (84 lines)
  imports `GEOM`, `layer`, `place`, `rows` — all four of `src/layout.js`'s
  exports, which are pure arithmetic over a node and edge list.
- `/home/lox/code/_fcl/rookery/todos/0.1.0/test/todo-search.test.mjs` (219 lines)
  and `test/todo-search-sync.test.mjs` (158 lines) import `score`, `passes` and
  `wire` from `src/todo-search.js`, driving `wire` through linkedom with
  `location` and `history` stubbed (`todo-search-sync.test.mjs:47-48`).

WHAT IS NOT COVERED: `/home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.js:122` —
`render(container)`. No test file references it. It reads its payload out of
`script.todo-graph-data` (line 123), builds the whole SVG with `createElementNS`
(`el`, lines 14-21) — `svg`, `defs`, `marker`, `g`, `rect`, `text`, `title`, `a`,
`path` — writes the classes `todo-graph-box`, `todo-graph-<status>` (32),
`idea-tag-todo-p<priority>` (39), `idea-tag-todo-<type>` (43), `todo-graph-rect`
(56), `todo-graph-label` (62), `todo-graph-link` (76), `todo-graph-svg` (143),
`todo-graph-edge` and `todo-graph-edge-unresolved` (100), `todo-graph-arrowhead`
(117), sets `data-rookery-tags` (48), defines the marker id `todo-graph-arrow`
(109) that every edge references as `marker-end: url(#todo-graph-arrow)` (102),
and finally swaps out `.todo-graph-fallback` (166) for the SVG it just built
(168).

So the arithmetic that decides where a node goes is tested and the drawing that
turns those numbers into a picture is not — which is the wrong way round for a
feature whose whole output is a picture. `src/todos.css` lines 442-529 carry the
`.todo-graph*` rules those classes exist to match, and nothing checks that the
two halves still agree.

THE SECOND THING WORTH PINNING is the `hidden`-attribute filter. `wire`
(`src/todo-search.js:81`) sets `row.el.hidden` (lines 176 and 178) and depends on
`.todo-search-row[hidden] { display: none }` at `src/todos.css:129-131` to
override `.todo-row`'s own `display: flex` at lines 40-41. `demo/rheo/check.sh`
lines 29-30 greps the built CSS for that rule precisely because the package's own
comment records what happens without it: the filter reorders the list and removes
nothing, which compiles clean, passes every existing suite, and is wrong only on
screen. A grep for a CSS rule is a proxy; an engine can assert the row is
actually not visible.

THE FIXTURE IS THE BUILT DEMO.
`/home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/` is compiled by that
package's existing `just check` (`/home/lox/code/_fcl/rookery/todos/0.1.0/Justfile:28`)
into `demo/rheo/build/html/index.html`, which already carries the graph, the
`#todos-search` widget, `#todo-table` and `#today-panel` — `check.sh` asserts
against all four.

DEPENDS ON the browser-harness bird, which supplies `loadPlaywright`, `serve`,
`requireBuild` and `run` from
`/home/lox/code/_fcl/rookery/test/browser/harness.mjs` and a root `just browser`
recipe that runs every `*/*/test/browser/*.mjs`.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/test/browser/graph.mjs

## Steps

1. Create `/home/lox/code/_fcl/rookery/todos/0.1.0/test/browser/graph.mjs`.
   Import `serve`, `requireBuild` and `run` from
   `../../../../test/browser/harness.mjs`, and `assert` from
   `node:assert/strict`.

2. Guard the build before anything else:

   ```js
   const ROOT = new URL("../../demo/rheo/build/html/", import.meta.url).pathname;
   requireBuild(`${ROOT}index.html`, "cd todos/0.1.0 && just check");
   ```

3. Serve `ROOT`, open `index.html` per engine via
   `run("todos-graph", async ({ newPage }) => { ... })`, and assert these five
   things and nothing else:

   1. **The graph replaces its fallback.** An `svg.todo-graph-svg` exists, and the
      `.todo-graph-fallback` that `render` swaps out (`src/todos.js:166`) is gone
      or hidden. Assert also that no `pageerror` and no console error was
      recorded — this is the first check in the repo that `render` runs without
      throwing in a real engine.
   2. **Nodes are drawn and positioned.** At least three `g.todo-graph-box`
      elements exist; every one holds a `rect.todo-graph-rect` and a
      `text.todo-graph-label`; and no two boxes share the same
      `getBoundingClientRect()` top-left. The last clause is what proves
      `layout.js`'s arithmetic reached the screen rather than every node landing
      at the origin — which is exactly the failure a pure-function test of
      `place` cannot see.
   3. **Edges resolve to their arrowhead.** At least one `path.todo-graph-edge`
      exists, its `d` attribute is a non-empty string, and its computed
      `marker-end` resolves rather than reading `none` — the marker is defined
      with id `todo-graph-arrow` at `src/todos.js:109` and referenced at line 102,
      and a broken reference is invisible in the markup.
   4. **A node links somewhere.** At least one `a.todo-graph-link` carries a
      non-empty `href`. Do not follow it.
   5. **A filtered row is actually invisible.** Find the `.todo-search` widget,
      type a string into its `.todo-search-input` that matches at least one row
      and excludes at least one other (read two rows' `data-todo-text` off the
      page to pick it, rather than hardcoding a query the demo content could
      change out from under). Then assert that an excluded `.todo-search-row` has
      a `getBoundingClientRect().height` of 0. This is the assertion
      `demo/rheo/check.sh:29-30` approximates by grepping the CSS for
      `.todo-search-row[hidden]`.

## Non-goals

- Do NOT change anything under `/home/lox/code/_fcl/rookery/todos/0.1.0/src/`.
  This bird observes; if an assertion fails, report it rather than fixing it.
- Do NOT change `demo/rheo/` content or `demo/rheo/check.sh`, and do NOT remove
  the CSS grep at `check.sh:29-30` even though assertion 3.5 supersedes it. That
  grep runs in CI today and this suite does not yet.
- Do NOT add a recipe to `/home/lox/code/_fcl/rookery/todos/0.1.0/Justfile`. The
  root `just browser` recipe finds every `*/*/test/browser/*.mjs` on its own.
- Do NOT touch the three existing `*.test.mjs` files.
- Do NOT assert exact coordinates or sizes. Every assertion above is a presence,
  a count, a "these two differ", or a zero height.
- Do NOT test `#todo-table` or `#today-panel`. Those are `@rookery/search`'s
  `#panel` and `#filter-panel` rendering todos data; the panel widgets belong to
  that package's own suite.
- Do NOT touch `.github/workflows/check.yml`.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just build && just check` —
   builds the demo into `demo/rheo/build/html/` and passes its own assertions, as
   it does today.
2. `cd /home/lox/code/_fcl/rookery && nix develop -c just browser` exits 0 and
   prints `ok todos-graph [webkit]`, `ok todos-graph [chromium]` and
   `ok todos-graph [firefox]`.
3. Prove the guard works: `mv todos/0.1.0/demo/rheo/build todos/0.1.0/demo/rheo/build.bak`,
   re-run step 2, confirm it exits non-zero naming
   `cd todos/0.1.0 && just check`. Move it back.
4. Prove assertion 3.5 bites: temporarily delete the
   `.todo-search-row[hidden] { display: none }` rule at
   `/home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css:129-131`, re-run
   `just build && just check` in the package and then step 2, and confirm the
   browser suite fails on the zero-height assertion. Restore the rule and rebuild.
   This is the one manual check worth doing, because it demonstrates the suite
   catching the exact on-screen-only bug the package's comment records.
5. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test-js` — the three
   existing node suites still pass, proving the glob `test/*.test.mjs` did not
   pick up the new file under `test/browser/`.