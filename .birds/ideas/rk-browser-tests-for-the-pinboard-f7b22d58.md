---
id: rk-browser-tests-for-the-pinboard-f7b22d58
short-id: f7
title: Browser tests for the pinboard
priority: 1
labels:
- feat-pinboard
- test-browser
deps:
- blocked-by:rk-stand-up-the-shared-browser-harness-cbc3ae56
- blocked-by:rk-pin-a-card-s-place-to-its-idea-id-836da185
closed: false
---
Everything `@rookery/pinboard` does is browser behaviour that `linkedom` cannot see.
Pointer capture, a drag that tracks a cursor, a card clamped to a board whose size
came from layout, a collapsed card shrinking to its handle — none of it exists in a
DOM object graph with no engine underneath. The package's own `test/*.test.mjs`
suites cover the arithmetic and the attribute writes, deliberately, and stop there.
This bird covers the rest, in three real engines.

## What it depends on, and what each dependency supplies

**The shared browser harness**, bird `rk-stand-up-the-shared-browser-harness-cbc3ae56`.
It puts `/home/lox/code/_fcl/rookery/test/browser/harness.mjs` in the tree, exporting
exactly four things:

- `loadPlaywright()` — resolves the three engines out of the nix store or, in CI, out
  of `node_modules`.
- `serve(dir)` — an `http` server on an ephemeral port, returning `{ origin, close }`.
- `requireBuild(path, hint)` — exits 1 with `browser: <path> is missing — run <hint>
  first` when a suite's fixture has not been built.
- `run(suiteName, fn)` — the engine loop. It runs `fn({ browser, engine, newPage })`
  against WebKit, Chromium and Firefox in that order, prints `ok <suite> [<engine>]`
  or `FAIL <suite> [<engine>]: <message>`, and owns process exit. Suites use
  `node:assert/strict` for assertions; the harness supplies none of its own. `newPage`
  returns a page that records every `pageerror` and every `console` message of type
  `error` into an array the suite can read.

It also adds a root `just browser` recipe that finds every `*/*/test/browser/*.mjs`
on its own — so this bird registers nothing anywhere, it just adds a file in the
right place.

**The pinboard itself**, bird `rk-pin-a-card-s-place-to-its-idea-id-836da185` and the three before it. What the suite asserts
against:

- The package is at `/home/lox/code/_fcl/rookery/pinboard/0.1.0/`, with a demo rheo
  project at `demo/rheo/` and a `just check` recipe that runs `rheo compile demo/rheo`.
- The board is `<div class="pinboard" data-pinboard="<board id>">`, holding one
  `<article class="pinboard-card" data-pinboard-id="<idea id>">` per note, each with a
  `<header class="pinboard-card-handle">` containing a `<button
  class="pinboard-card-toggle">` and the note's title as a link.
- A card's place is two CSS custom properties, `--pin-x` and `--pin-y`, consumed by
  `translate: var(--pin-x, 0) var(--pin-y, 0)` on an absolutely positioned card.
- A collapsed card carries `data-collapsed`, and
  `.pinboard-card[data-collapsed] .pinboard-card-body { display: none }` hides its body.
- The layout is stored in `localStorage` under `rookery-pinboard:<board id>`, as an
  object from idea id to `{x, y, collapsed}`, written at the end of a drag and on a
  collapse toggle.

Touches: pinboard/0.1.0/test/browser/board.mjs

## Steps

1. **Create `/home/lox/code/_fcl/rookery/pinboard/0.1.0/test/browser/board.mjs`**,
   importing the harness from `../../../../test/browser/harness.mjs` and `assert`
   from `node:assert/strict`, matching the other suites in this repo.

2. **Serve the demo's build output.** Call `requireBuild` on the demo's built
   `index.html` with the hint `just check`, then `serve` the demo's build directory
   and navigate to its origin. Assert against real `rheo compile` output rather than
   a hand-written fixture page — that is what makes the suite catch a change in what
   Typst emits, not only a change in the JavaScript.

3. **Assert the board booted.** After load, every `.pinboard-card` has a numeric
   non-empty `--pin-x` and `--pin-y`, no two cards share a position, and the page's
   recorded error array is empty. A board that throws during boot and leaves the
   cards stacked at the origin is the failure this catches, and it is invisible to
   any test without a real engine.

4. **Assert a drag moves a card.** Read a card's position, then drive a real gesture
   with Playwright's mouse API — `mouse.move` to the handle's centre from
   `boundingBox()`, `mouse.down()`, two or three `mouse.move` steps, `mouse.up()` —
   and assert the card's position changed by the pointer delta, within a pixel or
   two. Use several intermediate moves rather than one: a single jump does not
   exercise the `pointermove` path the way a real drag does, and some engines
   coalesce it away entirely.

5. **Assert the title link still works.** Click the card's title link, assert the page
   navigated to the note's own page, and go back. The drag implementation deliberately
   returns early when a press lands on `event.target.closest("a, button, input,
   summary")`, and a regression there silently turns the board's only navigation into
   a dead zero-pixel drag — which no unit test can see.

6. **Assert a drag does not start from the card body.** Press on `.pinboard-card-body`,
   move the pointer a hundred pixels, release, and assert the card's position is
   unchanged.

7. **Assert the collapse toggle hides the body.** Click `.pinboard-card-toggle`,
   assert the card gained `data-collapsed`, assert the body's computed `display` is
   `none`, assert the button's `aria-expanded` is `"false"`, and assert the card's
   rendered height shrank. The height assertion needs real layout and is the reason
   this belongs here rather than in `test/collapse.test.mjs`.

8. **Assert the layout survives a reload — the point of the whole package.** Drag a
   card to a known offset, collapse a different card, then `page.reload()`, and assert
   both cards come back exactly as they were left. Then assert the same thing after
   `page.goto` of the same URL in a fresh page in the same context, so a
   `bfcache`-restored page is not what is being measured.

9. **Assert a card with no stored entry is still placed.** Inject a stored layout via
   `page.evaluate` that names only some of the board's idea ids, reload, and assert
   that the named cards sit where the store says and the unnamed ones have distinct
   non-overlapping positions of their own. This is the "a note written since the board
   was last arranged" path, and it is the one most likely to regress into every new
   card landing on top of the first one.

10. **Clear storage between checks that need a clean board.** The harness's context is
    shared across a suite; call `page.evaluate(() => localStorage.clear())` and reload
    where a check assumes an unarranged board. A suite whose assertions depend on the
    order its own earlier assertions ran in is the thing to avoid here.

## Non-goals

- **No visual or screenshot comparison.** No `toHaveScreenshot`, no image baselines.
- **No new fixture project.** The package's existing `demo/rheo/` is the fixture. If
  it lacks enough notes to make a wrapping flow layout, add notes to
  `demo/rheo/content/index.typ` — but prefer working with what is there.
- **Do not modify `harness.mjs`.** If something is genuinely missing from it, say so
  rather than extending it here; other suites depend on its shape.
- **Do not add a Justfile recipe.** The root `just browser` recipe finds every
  `*/*/test/browser/*.mjs` on its own.
- **Do not edit `.github/workflows/check.yml`** — a separate bird runs the browser
  suites in CI.
- **No changes to any `src/` file.** If a real bug turns up, report it; do not fix it
  in a test bird.

## VERIFY

1. From `/home/lox/code/_fcl/rookery/pinboard/0.1.0`, `just check` succeeds, so the
   demo output the suite serves exists.
2. From `/home/lox/code/_fcl/rookery`, `nix develop -c just browser` exits 0 and its
   output includes `ok pinboard-board [webkit]`, `ok pinboard-board [chromium]` and
   `ok pinboard-board [firefox]`.
3. Deliberately break one thing and confirm the suite catches it: comment out the
   `makeDraggable(board)` call in `pinboard/0.1.0/src/pinboard.js`, run
   `just build` in the package and `nix develop -c just browser` again, and confirm it
   exits non-zero with a `FAIL pinboard-board [webkit]` line. Restore the call and
   confirm it passes again.