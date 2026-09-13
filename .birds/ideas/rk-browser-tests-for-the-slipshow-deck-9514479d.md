---
id: rk-browser-tests-for-the-slipshow-deck-9514479d
short-id: '95'
title: Browser tests for the slipshow deck
priority: 5
labels:
- test-browser
deps:
- blocked-by:rk-stand-up-the-shared-browser-harness-cbc3ae56
closed: false
---
`slipshow` is the most browser-dependent package in this repo and has the least
browser coverage of any of them. It is an endlessly scrolling presentation: a
scroll-and-transform camera, an SVG connector layer drawn from live element
geometry, and a keyboard-driven reveal state machine. None of that is tested in
an engine, and two exported functions are not tested at all.

WHAT IS COVERED TODAY, so this bird adds and does not duplicate. Three node
suites, all pure-function:

- `/home/lox/code/_fcl/rookery/slipshow/0.1.0/test/camera.test.mjs` (191 lines)
  imports `targetFor`, `clampTo`, `unfocusTarget` — all three of `src/camera.js`'s
  exports, which are pure by design.
- `/home/lox/code/_fcl/rookery/slipshow/0.1.0/test/reveal.test.mjs` (51 lines)
  imports `revealThrough`, `entersDeck`, `exitsDeck` — all three of
  `src/slipshow.js`'s exports.
- `/home/lox/code/_fcl/rookery/slipshow/0.1.0/test/edges.test.mjs` (35 lines)
  imports `edgePath` and `railX` only.

WHAT IS NOT COVERED:

- `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/edges.js:59` — `deckBox`, which
  walks `offsetParent`/`offsetLeft`/`offsetTop` (lines 62-64), finds the enclosing
  `.slip-row` with `closest` (67), reads `row.scrollLeft`/`scrollTop` (71-72) and
  `offsetWidth`/`offsetHeight` (74). Pure layout reading; unreachable without an
  engine.
- `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/edges.js:170` — `redraw`, which
  builds the SVG layer with `createElementNS` (177), inserts `.slip-edges` (155-161),
  draws one `path.slip-edge` per edge (194), resolves targets through
  `document.getElementById` off `data-slip-edges` (128-132), and reads
  `borderInlineStartWidth`/`borderInlineStartColor` out of `getComputedStyle`
  (94-98).
- Every DOM-driving function in
  `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slipshow.js`, none of which is
  exported and none of which any test can reach: `syncReveal` (93, toggles
  `.slip-revealed`), `applyScale` (142, writes `deck.style.transform`), `apply`
  (161, `window.scrollTo`, `row.scrollTo`, `history.replaceState`), `goTo` (223),
  `onKeydown` (289), `onClick` (317), `onResize` (322), `init` (330, which finds
  `div.slipshow`, adds `slipshow-revealing` at 356, reads `location.hash`, and
  registers keydown/click/resize/scroll listeners at 374-382).

`edges.test.mjs` lines 2-3 already say the untested pair is deferred to "the
`dag` example's own check". That check is `examples/dag/check.sh`, which greps
emitted markup and PDF text — it asserts what Typst wrote, never what the browser
did with it. This bird closes that gap properly.

THE FIXTURE IS THE BUILT DEMO, not a hand-written page. The deck markup is too
intricate to replicate by hand and a hand-written copy would drift from what
rheo actually emits. `/home/lox/code/_fcl/rookery/slipshow/0.1.0/demo/rheo/` is
compiled by that package's existing `just check` recipe
(`/home/lox/code/_fcl/rookery/slipshow/0.1.0/Justfile:25`) into
`demo/rheo/build/html/`, which already contains `index.html`, `explicit.html`,
`predicate.html`, `deck.html` and `crossdeck.html`. `deck.html` is the richest:
`demo/rheo/check.sh` line 49 asserts it carries 12 `section.slip`, line 95 that
two of them are `slip slip-fullscreen`, line 112 that one carries
`data-enter="focus"`.

DEPENDS ON the browser-harness bird, which supplies `loadPlaywright`, `serve`,
`requireBuild` and `run` from `/home/lox/code/_fcl/rookery/test/browser/harness.mjs`
and a root `just browser` recipe that runs every `*/*/test/browser/*.mjs`.

Touches: /home/lox/code/_fcl/rookery/slipshow/0.1.0/test/browser/deck.mjs

## Steps

1. Create `/home/lox/code/_fcl/rookery/slipshow/0.1.0/test/browser/deck.mjs`. Import
   `serve`, `requireBuild` and `run` from
   `../../../../test/browser/harness.mjs` and `assert` from `node:assert/strict`.

2. Guard the build first, before anything else runs:

   ```js
   const ROOT = new URL("../../demo/rheo/build/html/", import.meta.url).pathname;
   requireBuild(`${ROOT}deck.html`, "cd slipshow/0.1.0 && just check");
   ```

3. Serve `ROOT` once and open `deck.html` in each engine, via
   `run("slipshow-deck", async ({ newPage }) => { ... })`. Assert these five
   things, and nothing else:

   1. **The deck initialises.** Exactly one `div.slipshow` is present, and it
      carries a non-empty inline `transform` — `applyScale`
      (`src/slipshow.js:142`) writes `deck.style.transform`, so an empty one means
      `init` never ran. Assert also that no `pageerror` and no console error was
      recorded.
   2. **Reveal state is applied.** `div.slipshow` carries the class
      `slipshow-revealing` (written at `src/slipshow.js:356`) and at least one
      `section.slip` carries `slip-revealed` (written by `syncReveal`,
      `src/slipshow.js:96`).
   3. **A forward keypress advances the reveal.** Count
      `section.slip.slip-revealed`, press `ArrowRight`, wait for the count to
      change, and assert it increased by one. This is the first assertion in this
      repo that the keyboard handler at `src/slipshow.js:289` runs at all.
   4. **The camera scrolls.** Record `window.scrollY` (or the enclosing
      `.slip-row`'s `scrollLeft`, whichever the deck moves), press `ArrowRight`
      enough times to leave the first screen, and assert the recorded value
      changed. `apply` (`src/slipshow.js:161`) is the only thing that moves it.
   5. **The edge layer is drawn from real geometry.** Open whichever built page
      carries a `data-slip-edges` attribute — find it by reading the built HTML
      files in `ROOT` for that attribute rather than hardcoding a filename, since
      which demo page carries edges is not asserted anywhere today. On that page
      assert that a `.slip-edges` SVG layer exists as the deck's first element
      child (`ensureLayer`, `src/edges.js:155-161`), that it holds at least one
      `path.slip-edge` (`src/edges.js:194`), and that the path's `d` attribute is
      a non-empty string beginning with `M`. If NO built page carries
      `data-slip-edges`, fail with a message saying so rather than passing
      vacuously — a silently skipped assertion is worse than none.

4. If step 3.5 finds no `data-slip-edges` page in the demo, do NOT add one to the
   demo content to make the test pass. Fail, and say in the failure message that
   `examples/dag/` carries edges and the demo does not, so the operator can decide
   whether the suite should point at an example instead. Guessing here is how a
   demo grows content nobody asked for.

## Non-goals

- Do NOT change anything under `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/`.
  This bird only observes; if an assertion fails, report it, do not fix it.
- Do NOT change `demo/rheo/` content, `demo/rheo/check.sh`, or anything under
  `examples/`.
- Do NOT add a recipe to `/home/lox/code/_fcl/rookery/slipshow/0.1.0/Justfile`.
  The root `just browser` recipe finds every `*/*/test/browser/*.mjs` on its own.
- Do NOT convert `test/edges.test.mjs`, `test/camera.test.mjs` or
  `test/reveal.test.mjs`. They stay exactly as they are; this is additive.
- Do NOT assert exact pixel values anywhere. Every assertion above is a
  presence, a class, a count, or a "changed from before" — a deck's geometry
  depends on viewport and font metrics and pinning numbers would make this suite
  fail for reasons that are not bugs.
- Do NOT add screenshots or image baselines.
- Do NOT touch `.github/workflows/check.yml`.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just check` — builds the demo
   into `demo/rheo/build/html/` and passes its own assertions, as it does today.
2. `cd /home/lox/code/_fcl/rookery && nix develop -c just browser` exits 0 and
   prints `ok slipshow-deck [webkit]`, `ok slipshow-deck [chromium]` and
   `ok slipshow-deck [firefox]`.
3. Prove the guard works: `mv slipshow/0.1.0/demo/rheo/build slipshow/0.1.0/demo/rheo/build.bak`,
   re-run step 2, and confirm it exits non-zero with a message naming
   `cd slipshow/0.1.0 && just check`. Move it back.
4. Prove an assertion bites: temporarily change assertion 3.1 to require two
   `div.slipshow` elements, re-run step 2, confirm it exits non-zero naming
   `webkit` first. Restore it.
5. `cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test-js` — the three
   existing node suites still pass, proving the glob `test/*.test.mjs` did not
   pick up the new file under `test/browser/`.