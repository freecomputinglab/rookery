---
id: rk-fix-three-small-search-inconsistencies-a6e60962
short-id: a6
title: Fix three small search inconsistencies
priority: 2
labels:
- chore-search-review
deps: []
closed: false
---
Three small inconsistencies in `@rookery/search`, one per file: a target read
that bypasses the module's own helper, a positional pair index where the package
destructures everywhere else, and a DOM array rebuilt on every hover.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ,
/home/lox/code/_fcl/rookery/search/0.1.0/src/corpus.typ,
/home/lox/code/_fcl/rookery/search/0.1.0/src/modal.js

## 1. `_panel-shell` calls a bare `target()`

`/home/lox/code/_fcl/rookery/search/0.1.0/src/base.typ:12-22` defines `_target()`
and states why a bare `target()` is the wrong read in package scope: rheo injects
its `target()` polyfill into each vertebra's scope and not into a package's, and
`std.target()` reports EPUB as `"html"` where rheo's own context distinguishes
the two. Every other target read in this package goes through it —
`src/corpus.typ:230`, `src/ui.typ:120`, `src/ui.typ:238`.

`/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ:172` does not:

```typ
  if target() != "html" {
```

`panel.typ` already imports `base.typ` with `*` (line 40), so `_target` is in
scope. Change the line to `if _target() != "html" {`.

**This is a consistency fix, not a behaviour fix, and that is deliberate.** Both
reads answer `"html"` under a rheo HTML build and both send an EPUB build down
the paged branch, so the rendered output is unchanged. What changes is that the
file stops contradicting the rule its own dependency states — and the EPUB case
stops depending on which of two spellings was used.

## 2. A positional pair index in `#search-index`

`/home/lox/code/_fcl/rookery/search/0.1.0/src/corpus.typ:342-343`:

```typ
  let rows = selected.enumerate().map(pair => {
    let (i, e) = pair
```

Typst destructures a closure parameter with a parenthesised pattern, and this
package and `@rookery/core` both rely on it already — `src/panel.typ:99-100` and
`:165` in core's `theme.typ` use `((key, prop)) => ..`, and core's `state.typ`
uses `((i, body)) => ..`. Rewrite the two lines as:

```typ
  let rows = selected.enumerate().map(((i, e)) => {
```

and delete the now-redundant `let (i, e) = pair` line. Nothing else in the
closure changes.

## 3. The modal rebuilds its row array on every hover

`/home/lox/code/_fcl/rookery/search/0.1.0/src/modal.js:136-142`:

```js
    for (const hit of hits) {
      const row = renderRow(hit, terms, atoms);
      row.addEventListener("pointerenter", () => {
        select([...list.children].indexOf(row));
      });
      list.append(row);
    }
```

The handler spreads the whole live child list and scans it for the row, on every
pointerenter — to recover an index the loop already knows. Iterate with the index
and close over it:

```js
    for (const [i, hit] of hits.entries()) {
      const row = renderRow(hit, terms, atoms);
      row.addEventListener("pointerenter", () => select(i));
      list.append(row);
    }
```

This is exact rather than merely cheaper: `hits` and the list's children are
built in the same order in the same loop, and `select` clamps its argument
(`src/selection.js:53`), so the index is the same number `indexOf` was computing.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Do NOT

- Do not change any other target read, in this package or in `@rookery/core`.
- Do not change what `#search-index` emits — the row fields, their insertion
  order, or the `body-search`/`tags` conditionals around them.
- Do not touch `selection.js`, `bar.js` or `row.js`; the modal's `pointerenter`
  is the only site with this shape.
- Do not reword comments except where a sentence stops being true — a separate
  bird covers this package's comment prose.
- Do not edit anything under `test/`.

## VERIFY

All three are green today and must stay green:

```sh
cd /home/lox/code/_fcl/rookery/search/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/search/0.1.0 && just parity
cd /home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo && just check
```

Expected: `pass 123` / `fail 0`; six `OK` lines from parity; `demo/rheo OK`.

`just test` is the one that covers change 3 — the node suite drives the modal
under linkedom (`test/island.test.mjs`, `test/search.test.mjs` and the panel
suites) — and the demo covers 1 and 2, its `panels: 2, no island of their own,
10 rows behind a 2-row box` line being `_panel-shell`'s output and its
`pointer: src and base correct at both depths` line being `#search-index`'s.

Note that `just build` (`pnpm install && pnpm run build`) is NOT required for
any of these checks: the node suite imports `src/*.js` directly and the demo
resolves this package from source. Run it only if you want to confirm the vite
bundle still builds.