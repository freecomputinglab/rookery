---
id: rk-add-urlstate-js-url-param-state-2afe3277
short-id: 2a
title: Add urlstate.js, URL-param state primitives
priority: 3
labels:
- type:feature
- feat-url-state
deps: []
closed: false
---
Add `src/urlstate.js` to `@rookery/search`: the query-string primitives every
stateful widget in this family will use to survive a reload. This bird adds the
module, publishes it on the package's global, registers it in the manifest, and
unit-tests it. It wires NOTHING to any widget — that is a separate bird.

## Why this exists

`rheo watch` reloads a page with a hard `location.reload()` (rheo's own
`crates/html/src/server.rs`, the injected SSE script). Every filter widget in this
package keeps its state in a closure — `wirePanel`'s `facets` Map and `pressed` Set
at `/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.js:146-167` — so a rebuild
empties the filter box and un-presses every pill. Mirroring that state into the
query string is what makes it survive, and it makes a filtered view a copyable link
as a side effect.

Nothing in this repository reads or writes a query string today. Grepped and
confirmed: zero hits for `URLSearchParams`, `hashchange`, `pushState`,
`localStorage`, `sessionStorage` anywhere. The single precedent for URL state is
`slipshow/0.1.0/src/slipshow.js:212`, which uses `history.replaceState` for a slide
position and carries a comment at `:209-212` on why not `location.hash =`.

## Decisions already made — do not re-derive

- **`history.replaceState`, never `pushState`.** Back must keep leaving the page.
  Typing in a filter box would otherwise stack one history entry per keystroke.
  Same call, same reason, as `slipshow.js:212`.
- **Namespaced repeated params**, e.g.
  `?todos.q=rheo&todos.state=ready&todos.state=blocked`. One param per value,
  repeated — read with `URLSearchParams.getAll`, written with `delete` then
  `append`. NOT comma-joined: `_attr` in
  `/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ:46-59` permits any scalar
  value, and only `_multi-attr` at `:73-96` forbids whitespace, so a scalar facet
  value legitimately containing a comma would corrupt a joined param and there is
  no escaping rule to fall back on.
- **Pure functions over a query STRING, not over `location`.** The node suite here
  runs under linkedom (`test/panelinput.test.mjs` uses `parseHTML`), which provides
  no `history`, so anything reading `location`/`history` directly is untestable.
  Every function below takes and returns a string; only `commit` touches the
  address bar, and it is guarded so a node import is a no-op.
- **Params merge, never clobber.** A page can carry several synced widgets plus a
  tab key plus whatever a site put there. Each function rewrites only the params
  belonging to the key it was given, and leaves every other param — and their
  order — alone.

## Steps

1. Create `/home/lox/code/_fcl/rookery/search/0.1.0/src/urlstate.js`. It imports
   nothing from this package. Export exactly these seven bindings, with the
   contracts stated:

   - `readSync(key, search)` → `{ q, values }`. `search` is a query string with or
     without a leading `?`. `q` is the value of the `<key>.q` param, or `""` when
     absent. `values` is a `Map<string, Set<string>>`: one entry per OTHER param
     whose name starts with `key + "."`, the field being everything after that
     prefix, the Set holding every repeated value for it. A param not starting with
     the prefix is ignored entirely.
   - `writeSync(key, state, search)` → the new query string, WITHOUT a leading `?`,
     `""` when nothing is left. `state` is `{ q, values }` in `readSync`'s shape
     (`values` may be any iterable of `[field, iterable-of-values]` pairs, so a
     caller can hand over a `Map` directly). Delete every param starting with
     `key + "."` first, then append `<key>.q` when `q` is a non-empty string after
     trimming, then one `<key>.<field>` param per value. An empty `q` and an empty
     value set therefore write nothing, so a widget the reader has cleared leaves
     no trace in the URL. Every param outside this key's namespace survives.
   - `readParam(key, search)` → the value of the bare `<key>` param, or `null` when
     absent. This is the scalar case a radio group needs.
   - `writeParam(key, value, search)` → the new query string. `null`, `undefined` or
     `""` deletes the param instead of writing it.
   - `commit(search)` → writes `search` into the address bar in place, via
     `history.replaceState(null, "", pathname + qs + hash)` where `qs` is
     `search === "" ? "" : "?" + search`. Preserve the existing `location.hash` —
     rheo's link rule mints in-page `#handle` anchors and dropping one would break a
     reader's position. Return immediately, doing nothing, when
     `typeof location === "undefined" || typeof history === "undefined" || typeof history.replaceState !== "function"`.
     That guard is what lets node import this module and lets a linkedom test call
     it harmlessly.
   - `claimKey(key)` → `true` the first time a key is claimed on this page,
     `false` on every repeat, having emitted one
     `console.warn` naming the key and saying that the second widget will not sync.
     Backed by a module-level `Set`. Typst cannot see across two widget calls to
     assert this, so it is checked here.
   - `debounce(fn, ms = 200)` → a wrapped function that runs `fn` at most once per
     quiet `ms`, using `setTimeout`/`clearTimeout`. Exists so a caller does not
     `replaceState` per keystroke. Guard nothing: `setTimeout` exists under node.

   Write the file's header comment in this repo's style — see
   `/home/lox/code/_fcl/rookery/CLAUDE.md`, section "Comment style": one header
   block per file saying what the file is, present tense, no interior
   `// ---- Section ----` banners, no issue ids, comment the non-obvious only. The
   two facts worth a comment are the `replaceState`-not-`pushState` rule and why
   every function takes a string instead of reading `location`.

2. In `/home/lox/code/_fcl/rookery/search/0.1.0/src/search.js`:
   - add `import { readSync, writeSync, readParam, writeParam, commit, claimKey, debounce } from "./urlstate.js";`
     alongside the existing imports at lines 29-45. The comment at `:33-36`
     explains why this package imports AND re-exports rather than using
     `export ... from` alone — the global at the bottom names the values, so the
     import is required. Follow that.
   - add `export { readSync, writeSync, readParam, writeParam, commit, claimKey, debounce } from "./urlstate.js";`
     to the re-export block at lines 47-51.
   - add the same seven names to the `globalThis.RookerySearch ??= { .. }` object
     at lines 154-172. This is the surface `@rookery/todos` will feature-detect
     later, exactly as `todos/0.1.0/src/todo-search.js:95-96` already
     feature-detects `globalThis.RookerySearch` for the `tags:` language.
   - do NOT call anything from `init()` (lines 59-140) in this bird. Nothing is
     wired yet.

3. In `/home/lox/code/_fcl/rookery/search/0.1.0/typst.toml`, add `"src/urlstate.js"`
   to the `[tool.rheo.source.html]` `js_scripts` array at lines 45-60. Put it
   FIRST, before `"src/text.js"`: the list is dependency-ordered and this module
   depends on nothing. THIS STEP IS LOAD-BEARING AND EASY TO SKIP — the comment at
   lines 41-44 says why: rheo's asset copy acts on exactly this list and not on a
   scan of import statements, so a file left out never lands in a consuming
   project's output even though the browser's own module graph would have found it,
   and nothing warns.

4. Create `/home/lox/code/_fcl/rookery/search/0.1.0/test/urlstate.test.mjs`, in the
   shape the existing suite uses — `import { test } from "node:test";`,
   `import assert from "node:assert/strict";`, one `test("...", () => {..})` per
   claim. No DOM needed: `URLSearchParams` is a node global. Cover at least:
   - `readSync("todos", "todos.q=rheo&todos.state=ready&todos.state=blocked")`
     gives `q === "rheo"` and `values.get("state")` equal to
     `new Set(["ready", "blocked"])`.
   - `readSync` on a string with a leading `?` behaves identically.
   - `readSync("todos", "ideas.t=cfp")` gives `q === ""` and an empty `values` —
     another widget's params are invisible to this one.
   - `writeSync` round-trips: feeding `readSync`'s output back to `writeSync` with
     the same key yields a string `readSync` parses to the same state.
   - `writeSync("todos", { q: "", values: new Map() }, "todos.q=x&tab=todos")`
     returns just `"tab=todos"` — clearing a widget removes its params and keeps
     everyone else's.
   - a facet value containing a comma and a space survives a
     `writeSync`/`readSync` round trip unchanged. This is the case that rules out
     comma-joining, so pin it.
   - `readParam`/`writeParam` for the scalar case, including that
     `writeParam("tab", null, "tab=todos&todos.q=x")` returns `"todos.q=x"`.
   - `claimKey("a")` is `true` then `false`, and `claimKey("b")` is `true`.
   - `commit("a=1")` does not throw when called with no `history` present.

## Do NOT

- Do NOT touch `src/panel.js`, `src/panel.typ`, `src/filter-panel.typ`, or anything
  under `todos/`. No widget is wired in this bird.
- Do NOT add a `sync:` parameter to any Typst function here.
- Do NOT use `pushState`, `location.hash =`, `localStorage` or `sessionStorage`.
- Do NOT read `location` or `history` from any function except `commit`.
- Do NOT add a dependency to `package.json`. This module needs none.
- Do NOT touch `search/0.1.0/readme.md` — a later bird documents the whole feature
  in one pass, so that 1571-line file has a single writer.
- Do NOT edit `dist/` by hand. It is a gitignored build artifact.

## VERIFY

From `/home/lox/code/_fcl/rookery/search/0.1.0`:

```sh
just test
just parity
just build
```

`just test` (`node --test test/*.test.mjs`) must be fully green, including the new
`urlstate.test.mjs` and every pre-existing file. `just parity` must still pass — it
diffs the Typst and JavaScript copies of the ranking rule and this bird touches
neither, so a failure there means something unrelated broke. `just build`
(`pnpm install && pnpm run build`) must succeed, proving vite can still bundle the
entrypoint with the new import in it.

Then, to confirm the manifest edit actually took:

```sh
grep -n urlstate typst.toml
```

must print a line inside the `[tool.rheo.source.html]` array, above `src/text.js`.