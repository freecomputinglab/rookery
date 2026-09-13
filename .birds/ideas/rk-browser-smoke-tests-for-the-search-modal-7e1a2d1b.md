---
id: rk-browser-smoke-tests-for-the-search-modal-7e1a2d1b
short-id: 7e
title: Browser smoke tests for the search modal
priority: 1
labels:
- fix-safari-search-modal
- test-browser
deps:
- blocked-by:rk-wire-search-triggers-before-the-index-7974cadf
- blocked-by:rk-stand-up-the-shared-browser-harness-cbc3ae56
closed: false
---
A reader on Safari (macOS and iPad) reported that clicking the search button in a
rookery site's header does nothing, while the same click on Firefox and Brave
opens the modal. `#search-modal`'s actual behaviour — does the trigger open the
dialog, does it render rows, does Escape close it, does a failed index leave a
dead button — is asserted nowhere, because all 18 of this package's suites run
under node with linkedom, which has no `<dialog>`, no top layer, no layout and no
`fetch`. Diagnosing that report meant standing a browser harness up by hand.

This bird pins the modal's behaviour in three real engines, WebKit among them.

WHAT THE HAND-BUILT HARNESS ALREADY ESTABLISHED, so the suite starts from
measured facts rather than guesses. Driven under Playwright's WebKit 26.5 (the
Safari 26 engine), Chromium and Firefox against the built HTML of two real
rookery sites, the modal opens at an identical rect in all three, on a 1280x900
desktop viewport and on an emulated iPad with a touch tap. A top-layer `<dialog>`
was also checked against every ancestor style that could plausibly clip or
contain it — `overflow: hidden`, `transform`, `filter`, `backdrop-filter`,
`contain: paint`, `will-change`, `isolation`, `opacity` — and WebKit escapes all
of them exactly as Blink and Gecko do. Aborting or 500-ing the index fetch, by
contrast, makes the trigger inert in all three engines with nothing logged. That
last one is the reported defect, and it is fixed by the bird this one is blocked
behind.

THE FIXTURE IS THE BUILT DEMO, not a hand-written page.
`/home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo/content/index.typ` places
`#search-bar()` at line 79 and `#search-modal()` at line 80, and that project is
compiled by its own `just check`
(`/home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo/Justfile`) into
`demo/rheo/build/html/`. Testing what rheo actually emits is the point; a
hand-written approximation of the markup would drift from it silently.

DEPENDS ON two birds:

- the browser-harness bird, which supplies `loadPlaywright`, `serve`,
  `requireBuild` and `run` from
  `/home/lox/code/_fcl/rookery/test/browser/harness.mjs` and a root
  `just browser` recipe that runs every `*/*/test/browser/*.mjs`;
- the bird that wires the search trigger before the index loads, without which
  case 3.5 below has no behaviour to assert — a failed index currently leaves the
  trigger unwired and the empty state reading `No match found`.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/test/browser/modal.mjs

## Steps

1. Create `/home/lox/code/_fcl/rookery/search/0.1.0/test/browser/modal.mjs`.
   Import `serve`, `requireBuild` and `run` from
   `../../../../test/browser/harness.mjs`, and `assert` from
   `node:assert/strict`.

2. Guard the build first:

   ```js
   const ROOT = new URL("../../demo/rheo/build/html/", import.meta.url).pathname;
   requireBuild(`${ROOT}index.html`, "cd search/0.1.0/demo/rheo && just check");
   ```

3. Serve `ROOT` and open `index.html` per engine via
   `run("search-modal", async ({ newPage }) => { ... })`. Assert these five things
   and nothing else.

   1. **The trigger opens the modal.** Click `.rookery-search-trigger`, assert the
      `dialog[data-rookery-search]` reports `open === true`, matches `:modal`, has
      a `getBoundingClientRect().height` greater than zero, and that
      `document.activeElement` is the `.rookery-search-input` inside it. Assert no
      `pageerror` and no console error was recorded.
   2. **Rows render for a query.** Type a query into the modal's input and assert
      at least one `.rookery-search-row` appears in `.rookery-search-list`. Pick
      the query by reading a real row's title off the page first, rather than
      hardcoding a word the demo content could change out from under.
   3. **Escape closes it.** Press `Escape`, assert `open === false`. Note that
      `modal.js` handles Escape explicitly rather than leaving it to the dialog's
      own cancel algorithm, because a `type="search"` input with a value consumes
      the first press — so do this with a NON-EMPTY query in the field, which is
      the case the explicit handler exists for.
   4. **A touch tap opens it too.** Repeat case 1 in a context created with
      `{ hasTouch: true, isMobile: true, viewport: { width: 820, height: 1180 } }`,
      using `.tap()` rather than `.click()`. An iPad was half the bug report.
   5. **A failed index still opens the modal, loudly.** Route the index request to
      `route.abort()` before loading the page — the built island carries
      `data-rookery-search-src`, so the request is the JSON file it names. Then
      click the trigger and assert three things: the dialog opens
      (`open === true`); the pane's text contains `Search index unavailable`; and
      at least one captured console message of type `warning` mentions
      `@rookery/search`. Before the bird this one is blocked behind, all three of
      those fail — the trigger is never wired at all — which is exactly the
      reported Safari symptom.

## Non-goals

- Do NOT change anything under `/home/lox/code/_fcl/rookery/search/0.1.0/src/`.
  This bird observes; if an assertion fails, report it rather than fixing it.
- Do NOT assert anything about `#search-bar`'s dropdown or the preview pane's
  fetched content. Those belong to the separate search-dropdown browser bird,
  which writes `test/browser/bar.mjs` — a different file, so the two can fly at
  once.
- Do NOT test `#panel` or `#filter-panel`, which are also on the demo page.
- Do NOT change `demo/rheo/` content or its `check.sh`.
- Do NOT add a recipe to `/home/lox/code/_fcl/rookery/search/0.1.0/Justfile`. The
  root `just browser` recipe finds every `*/*/test/browser/*.mjs` on its own.
- Do NOT add visual or screenshot comparison, and do NOT assert exact pixel
  positions. Every assertion above is a presence, a boolean, a count, a non-zero
  height, or a substring.
- Do NOT touch any existing `*.test.mjs` file, `test/internal.mjs` or
  `test/parity.mjs`.
- Do NOT touch `.github/workflows/check.yml`.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just build` then
   `cd /home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo && just check` — builds
   the demo into `build/html/` and passes its own assertions, as it does today.
2. `cd /home/lox/code/_fcl/rookery && nix develop -c just browser` exits 0 and
   prints `ok search-modal [webkit]`, `ok search-modal [chromium]` and
   `ok search-modal [firefox]`.
3. Prove the guard works: `mv search/0.1.0/demo/rheo/build search/0.1.0/demo/rheo/build.bak`,
   re-run step 2, confirm it exits non-zero naming
   `cd search/0.1.0/demo/rheo && just check`. Move it back.
4. Prove case 3.5 bites: temporarily move the `.rookery-search-trigger` click
   listener in `/home/lox/code/_fcl/rookery/search/0.1.0/src/search.js` back below
   the index `await`, re-run step 2, and confirm the suite fails on the
   aborted-index case naming `webkit` first. Restore it.
5. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just test` — the 18 existing
   node suites still pass, proving the glob `test/*.test.mjs` did not pick up the
   new file under `test/browser/`.