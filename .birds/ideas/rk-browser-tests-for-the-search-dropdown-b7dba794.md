---
id: rk-browser-tests-for-the-search-dropdown-b7dba794
short-id: b7d
title: Browser tests for the search dropdown
priority: 1
labels:
- test-browser
deps:
- blocked-by:rk-stand-up-the-shared-browser-harness-cbc3ae56
closed: true
---
Two of `@rookery/search`'s five browser modules are untested, and they are the
two that need an engine most.

`/home/lox/code/_fcl/rookery/search/0.1.0/src/bar.js` has **no test file at
all**. Its sole export, `wire` (line 11), is `#search-bar`'s dropdown: a combobox
over the island's rows. Nothing under
`/home/lox/code/_fcl/rookery/search/0.1.0/test/` imports it. The behaviour that
matters there is behaviour linkedom has no model for:

- lines 74-76 and 77-79 — the ArrowDown/ArrowUp branches call
  `ev.preventDefault()` specifically to stop a `type="search"` input moving its
  caret to the end or start of the value. Whether the caret moved is the whole
  assertion and there is no caret in a DOM object graph.
- lines 88-91 — Enter reads `row.href` off the selected `<a>` and assigns
  `window.location.href`, i.e. navigates.
- line 96 — Escape calls `input.blur()`, a real focus-model operation.
- line 73 — every one of those branches is gated on
  `root.dataset.rookerySearchOpen`, written alongside `aria-expanded` at lines
  40-41.
- `/home/lox/code/_fcl/rookery/search/0.1.0/src/search.js:109` — the
  document-level `pointerdown` listener that dismisses a dropdown when the reader
  presses outside it. Its own comment says `pointerdown` rather than `click` was
  chosen *because it fires before focus moves*; that ordering is exactly what a
  synthetic dispatch cannot reproduce.

`/home/lox/code/_fcl/rookery/search/0.1.0/src/preview.js` is half-tested.
`extractNote` (line 66) is covered by `test/extractnote.test.mjs` (157 lines) via
`test/internal.mjs:20`, driven with linkedom's `DOMParser`. But `fetchNote` (line
110) and `previewCache` (line 16) are referenced by no test file. That is the
glue: `fetch` (112), `res.text()` (113), `new DOMParser().parseFromString` (118),
`new URL(href, document.baseURI)` (119), and the memoisation that must remember a
MISS as a resolved `null` so a 404 is not re-fetched on every arrow key. The pure
extraction is pinned and the networked half around it is not.

THE FIXTURE IS THE BUILT DEMO.
`/home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo/content/index.typ` places
`#search-bar()` at line 79 and `#search-modal()` at line 80 on one page, and
that demo is compiled by its own `just check`
(`/home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo/Justfile`) into
`demo/rheo/build/html/`. Both surfaces this bird tests are therefore on one real
page emitted by rheo, with a real index and real minted note pages for the
preview to fetch.

DEPENDS ON the browser-harness bird, which supplies `loadPlaywright`, `serve`,
`requireBuild` and `run` from
`/home/lox/code/_fcl/rookery/test/browser/harness.mjs` and a root `just browser`
recipe that runs every `*/*/test/browser/*.mjs`.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/test/browser/bar.mjs

## Steps

1. Create `/home/lox/code/_fcl/rookery/search/0.1.0/test/browser/bar.mjs`. Import
   `serve`, `requireBuild` and `run` from
   `../../../../test/browser/harness.mjs`, and `assert` from
   `node:assert/strict`.

2. Guard the build first:

   ```js
   const ROOT = new URL("../../demo/rheo/build/html/", import.meta.url).pathname;
   requireBuild(`${ROOT}index.html`, "cd search/0.1.0/demo/rheo && just check");
   ```

3. Serve `ROOT` and open `index.html` per engine via
   `run("search-bar", async ({ newPage }) => { ... })`. Assert these six things
   and nothing else.

   Pick the query string by reading a row's own text off the built index rather
   than hardcoding a word the demo content could change out from under — type a
   prefix of a real `.rookery-search-row` title.

   1. **The dropdown opens on typing and closes on an empty query.** Click
      `.rookery-search-input` inside the `#search-bar` root (the root is the
      `[data-rookery-search]` element that is NOT the dialog), type the query, and
      assert the root's `data-rookery-search-open` is `"true"`, that
      `aria-expanded` on the input is `"true"`, and that at least one
      `.rookery-search-row` is present in `.rookery-search-results`. Clear the
      field and assert both attributes read `"false"`.
   2. **Arrow keys move the selection and do not move the caret.** With the
      dropdown open, record `input.selectionStart`, press `ArrowDown`, and assert
      that exactly one row carries `data-rookery-search-selected="true"` AND that
      `input.selectionStart` is unchanged. That second clause is what `bar.js:75`
      exists for and is untestable without a caret.
   3. **Ctrl-n and Ctrl-p move it too.** Press `Control+n`, assert the selected
      row advanced by one; press `Control+p`, assert it went back. Same keys the
      modal takes, which is the point of them.
   4. **Enter navigates to the selected row.** With a row selected, read its
      `href`, press `Enter`, wait for navigation, and assert the page's URL is
      that href. Then go back to `index.html` for the remaining cases.
   5. **A press outside the bar dismisses it, and the query survives.** Reopen
      the dropdown, then dispatch a real pointer press on some element outside the
      bar — use the page's own mouse so `pointerdown` fires for real, not
      `element.dispatchEvent`. Assert `data-rookery-search-open` is `"false"` and
      that `input.value` is still the query the reader typed. Then click back INTO
      the input and assert it is STILL `"false"` — `bar.js`'s `dismissed` flag
      (line 30) says a dismissed dropdown stays shut until new typing, and that is
      the rule worth pinning.
   6. **The preview pane fetches a note's real rendering.** Open the modal
      (click `.rookery-search-trigger`), type the query, and assert that
      `.rookery-search-preview` ends up containing a
      `div.idea-window.idea-window-plain` — the wrapper `extractNote` builds at
      `src/preview.js:75-84` — and that it holds at least one child. Assert also
      that `.rookery-search-preview` does NOT carry
      `data-rookery-search-loading` once it has settled, since
      `modal.js` deletes that flag on every path and a spinner left running is a
      real failure mode. This is the only assertion anywhere that `fetchNote`
      works.

## Non-goals

- Do NOT change anything under `/home/lox/code/_fcl/rookery/search/0.1.0/src/`.
  This bird observes; if an assertion fails, report it rather than fixing it.
- Do NOT assert anything about `#search-modal`'s own open/close/empty-state
  behaviour. That is the separate search-modal browser bird, which writes
  `test/browser/modal.mjs` — a different file, so the two can fly at once.
  Case 3.6 here opens the modal only as the way to reach the preview pane.
- Do NOT test `#panel` or `#filter-panel`, which are also on the demo page.
- Do NOT change `demo/rheo/` content or its `check.sh`.
- Do NOT add a recipe to `/home/lox/code/_fcl/rookery/search/0.1.0/Justfile`. The
  root `just browser` recipe finds every `*/*/test/browser/*.mjs` on its own.
- Do NOT touch any existing `*.test.mjs` file, `test/internal.mjs`, or
  `test/parity.mjs`.
- Do NOT touch `.github/workflows/check.yml`.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just build` then
   `cd /home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo && just check` — builds
   the demo into `build/html/` and passes its own assertions, as it does today.
2. `cd /home/lox/code/_fcl/rookery && nix develop -c just browser` exits 0 and
   prints `ok search-bar [webkit]`, `ok search-bar [chromium]` and
   `ok search-bar [firefox]`.
3. Prove the guard works: `mv search/0.1.0/demo/rheo/build search/0.1.0/demo/rheo/build.bak`,
   re-run step 2, confirm it exits non-zero naming
   `cd search/0.1.0/demo/rheo && just check`. Move it back.
4. Prove case 3.2 bites: temporarily delete the `ev.preventDefault()` at
   `/home/lox/code/_fcl/rookery/search/0.1.0/src/bar.js:75`, re-run step 2, and
   confirm the caret assertion fails. Restore it.
5. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just test` — the 18 existing
   node suites still pass, proving the glob `test/*.test.mjs` did not pick up the
   new file under `test/browser/`.