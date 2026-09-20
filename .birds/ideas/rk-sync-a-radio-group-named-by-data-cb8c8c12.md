---
id: rk-sync-a-radio-group-named-by-data-cb8c8c12
short-id: cb
title: Sync a radio group named by data attribute
priority: 3
labels:
- type:feature
- feat-url-state
deps:
- blocked-by:rk-add-urlstate-js-url-param-state-2afe3277
closed: true
---
Add `src/urlsync.js` to `@rookery/search`: a declarative sync for a radio group
named by a data attribute, so a CSS-only tab strip can keep its active pane across
a reload without the consuming site writing a line of JavaScript.

## Why this exists, and why it is generic

The page this whole feature is for is waterline's `rookery/index.typ`, whose tab
strip is CSS-only — one radio per pane and `:checked ~` doing the switching, in
that site's own `rookery/_lib/template.typ` — and that site ships NO JavaScript of
its own, anywhere. Its only script is the one this package injects. So the choice
is either that site grows a first script, a first asset declaration and a first
build concern, or this package offers a declarative hook and the site adds one
attribute to markup it already emits. The hook is much the cheaper of the two, and
it is generic: nothing here knows what a tab is, only that a radio group's
selection can live in a query parameter.

Naming it by ATTRIBUTE rather than by class follows what this package already does
everywhere — a bar is found by `data-rookery-search`, whose value is the id of the
island it reads (`src/search.js:22-26`), and panels by `.panel` plus their own
`data-panel-*` declarations. Ids are never hardcoded in emitted markup here,
because markup carrying one cannot be placed twice on a page.

## Prerequisite already in the tree

`/home/lox/code/_fcl/rookery/search/0.1.0/src/urlstate.js` exists, is exported from
`src/search.js`, and is listed first in `typst.toml`'s `[tool.rheo.source.html]`
`js_scripts`. This bird uses three of its exports and must not change them:

- `readParam(key, search)` → the value of the bare `<key>` param, or `null`.
- `writeParam(key, value, search)` → a new query string; `null`/`""` deletes the
  param, and every param outside this key survives untouched.
- `commit(search)` → `history.replaceState` in place, preserving `location.hash`,
  and a no-op where `location`/`history` are absent.
- `claimKey(key)` → `false` plus one `console.warn` on a repeated key.

## Decisions already made — do not re-derive

- **`getAttribute("value")`, never `.value`.** A radio with no `value` attribute
  reports `.value === "on"` in the DOM. Reading the property would write `?tab=on`
  for every pane of a strip whose radios carry no values — which is exactly the
  markup this package will meet, since a CSS-only tab strip has no reason to have
  had values before now. A radio whose `value` attribute is absent or empty is
  therefore SKIPPED, and a group in which no radio has one syncs nothing at all.
- **Nothing is written until the reader acts.** Do not write the param on init from
  the default selection: a page nobody has touched should have a clean URL.
- **A param naming no radio in the group is ignored**, leaving the markup's own
  `checked` default standing. A stale link must not deselect every pane.
- **`history.replaceState`, never `pushState`** — Back keeps leaving the page. Same
  rule, same reason, as `slipshow/0.1.0/src/slipshow.js:212`.

## Steps

1. Create `/home/lox/code/_fcl/rookery/search/0.1.0/src/urlsync.js`, importing
   `readParam`, `writeParam`, `commit` and `claimKey` from `./urlstate.js` and
   nothing else. Export two functions:

   - `wireRadioGroup(container, key)`. Collect
     `container.querySelectorAll('input[type="radio"]')`, keep only those whose
     `getAttribute("value")` is a non-empty string, and return `null` when none
     remain or when `claimKey(key)` is `false`. Otherwise:
     - restore: `const want = readParam(key, location.search)`, and if `want` is
       non-null and one of the collected radios has that value, set that radio's
       `.checked = true` and every other collected radio's `.checked = false`.
       Setting `.checked` on a radio also unchecks its `name`-group siblings in a
       real browser, but do it explicitly anyway — a group is scoped to this
       container here, not to a `name`, so a container holding two `name` groups
       must not end up with two checked radios.
     - persist: add one `change` listener per collected radio that calls
       `commit(writeParam(key, radio.getAttribute("value"), location.search))`.
       Read `location.search` inside the handler, per event, never captured: a
       synced panel on the same page writes between two of these and a stale string
       would drop its params.
     - return something truthy the caller can count (e.g. `{ container, key }`).
   - `initUrlSync()`. For every `document.querySelectorAll("[data-rookery-url-radio]")`,
     call `wireRadioGroup(el, el.dataset.rookeryUrlRadio)`, skipping an element
     whose attribute value is empty.

   Write the file header in this repo's register — see
   `/home/lox/code/_fcl/rookery/CLAUDE.md`, "Comment style": one header block
   saying what the file is, present tense, no interior section banners, no issue
   ids, comment only the non-obvious. The facts worth a comment are the
   `getAttribute("value")`-not-`.value` rule, why nothing is written until the
   reader acts, and that this module knows nothing about tabs.

2. In `/home/lox/code/_fcl/rookery/search/0.1.0/src/search.js`:
   - import `initUrlSync` (and `wireRadioGroup`) from `./urlsync.js`, alongside the
     existing imports at lines 29-45. The comment at lines 33-36 explains why this
     file imports AND re-exports rather than using `export ... from` alone — the
     global at the bottom names the values.
   - re-export both from the block at lines 47-51.
   - add both to `globalThis.RookerySearch ??= { .. }` at lines 154-172.
   - call `initUrlSync();` inside `init()` immediately after the existing
     `initPanels();` at line 63. That placement matters and the comment at lines
     60-62 already says why for panels: everything above the early `return` at line
     71 runs on a page that carries no search index at all, and a page with a tab
     strip and no index is exactly such a page. Put it above that return or it will
     silently never run.

3. In `/home/lox/code/_fcl/rookery/search/0.1.0/typst.toml`, add
   `"src/urlsync.js"` to the `[tool.rheo.source.html]` `js_scripts` array. It must
   come AFTER `"src/urlstate.js"` (it imports it) and BEFORE `"src/search.js"`
   (which imports it). THIS STEP IS LOAD-BEARING — the comment just above that
   array says rheo's asset copy acts on exactly this list and not on a scan of
   import statements, so a file left out never lands in a consuming project's
   output even though the browser's own module graph would have found it, and
   nothing warns.

4. Create `/home/lox/code/_fcl/rookery/search/0.1.0/test/urlsync.test.mjs`, in the
   shape of `test/panelinput.test.mjs`: `parseHTML` from linkedom,
   `globalThis.document = document`, `import { test } from "node:test"`,
   `import assert from "node:assert/strict"`. Because `commit` needs an address bar
   and linkedom may not supply one, stub it explicitly — that suite already assigns
   `globalThis.document` by hand, so this is the same move:

   ```js
   let captured = null;
   globalThis.location = { pathname: "/index.html", search: "", hash: "" };
   globalThis.history = { replaceState: (_a, _b, url) => { captured = url; } };
   ```

   Reset both between tests. A fixture in the shape the consuming site emits:

   ```html
   <div class="tabs" data-rookery-url-radio="tab">
     <input type="radio" class="tab-radio" name="tabs-index" value="today" checked>
     <input type="radio" class="tab-radio" name="tabs-index" value="todos">
     <input type="radio" class="tab-radio" name="tabs-index" value="ideas">
   </div>
   ```

   Cover at least:
   1. `location.search = "tab=todos"` before wiring leaves the second radio checked
      and the first unchecked.
   2. `location.search = "tab=nope"` leaves the markup's own `checked` default
      standing, with exactly one radio checked.
   3. Wiring alone writes nothing: `captured` is still `null`.
   4. Dispatching `change` on the third radio puts `tab=ideas` in `captured`.
   5. Merging: with `location.search = "todos.q=x"`, a `change` keeps `todos.q=x`
      and adds `tab=`.
   6. A group whose radios carry no `value` attribute syncs nothing — no
      `replaceState` on `change`, and specifically no `tab=on`. This is the
      `.value` trap, so pin it.
   7. Two containers declaring the same key: the second is refused (`wireRadioGroup`
      returns `null`) and a `change` on its radios writes nothing.

## Do NOT

- Do NOT touch `src/panel.js`, `src/panel.typ` or `src/filter-panel.typ`. Panel
  syncing is a different bird and this module shares no code with it beyond
  `urlstate.js`.
- Do NOT touch `src/urlstate.js`. Needing to change it means the contract above was
  misread.
- Do NOT sync checkboxes, `<select>`, or `<details>` here. Radios only; the other
  shapes have no caller yet and each has its own question about multiplicity.
- Do NOT add a Typst function or any `.typ` file in this bird. This package emits no
  tab strip; the hook is for a consuming site's own markup.
- Do NOT touch anything under `todos/`.
- Do NOT touch `search/0.1.0/readme.md`; one later bird documents the whole feature
  so that file has a single writer.
- Do NOT use `pushState`, `location.hash`, `localStorage` or `sessionStorage`.
- Do NOT edit `dist/`. It is a gitignored build artifact.

## VERIFY

From `/home/lox/code/_fcl/rookery/search/0.1.0`:

```sh
just test
just parity
just build
rheo compile demo/rheo
```

`just test` green including the new `urlsync.test.mjs` and every pre-existing file.
`just build` proves vite still bundles the entrypoint with the new import in it.
`rheo compile demo/rheo` proves the manifest edit did not break asset resolution in
a real rheo project (that fixture reads `@rookery/*` out of this tree via
`[packages.rookery] path = "../../../.."`).

Then confirm the script actually lands, which is the failure mode the manifest
comment warns about:

```sh
grep -rn urlsync demo/rheo/build/ | head
```

must show `urlsync.js` copied into the built output. If it does not, step 3 was
skipped or ordered wrongly.