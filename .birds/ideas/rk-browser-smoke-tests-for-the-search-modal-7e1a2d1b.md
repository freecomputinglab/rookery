---
id: rk-browser-smoke-tests-for-the-search-modal-7e1a2d1b
short-id: 7e
title: Browser smoke tests for the search modal
priority: 5
labels:
- fix-safari-search-modal
deps:
- blocked-by:rk-wire-search-triggers-before-the-index-7974cadf
closed: false
---
This package's test suite is 17 `*.test.mjs` files running under node with
linkedom standing in for a browser. linkedom is a DOM, not an engine: it has no
`<dialog>`, no top layer, no `fetch`, no layout and no event dispatch of the kind
a real click produces. So the whole of `#search-modal`'s actual behaviour — does
the trigger open the dialog, does it render rows, does Escape close it, does a
failed index leave a dead button — is untested, and a Safari bug report against
exactly that path had to be diagnosed by bootstrapping a browser harness by hand.

This bird makes that harness part of the package. Playwright's `webkit` build is
the Safari engine, so the same suite covers the one browser nobody here can run
natively, alongside Chromium and Firefox.

WHAT THE HARNESS ALREADY PROVED, so the suite starts from a known state rather
than a guess. Driven against the built HTML of a real rookery site under
Playwright's WebKit 26.5, Chromium and Firefox, the modal opens at an identical
rect in all three, on desktop and on an emulated iPad with a touch tap. Aborting
or 500-ing the index fetch makes the trigger inert in all three with nothing
logged — the defect the preceding bird fixes. These are the assertions worth
pinning.

DEPENDS ON the bird that wires the trigger before the index loads: two of the
four cases below assert behaviour that does not exist until that has landed.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/test/browser.mjs, /home/lox/code/_fcl/rookery/search/0.1.0/test/fixture/page.html, /home/lox/code/_fcl/rookery/search/0.1.0/flake.nix, /home/lox/code/_fcl/rookery/search/0.1.0/Justfile, /home/lox/code/_fcl/rookery/search/0.1.0/package.json

## Steps

1. Add the browsers and the driver to the package's own devShell.
   `/home/lox/code/_fcl/rookery/search/0.1.0/flake.nix` currently lists only
   `nodejs` and `pnpm` in `buildInputs`. Add `playwright-driver.browsers` and
   set the two environment variables Playwright needs on NixOS, which cannot
   download or run its own browser binaries here:

   ```nix
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            pnpm
            playwright-driver.browsers
          ];
          # Playwright downloads browser binaries by default and the downloads
          # are dynamically linked against libraries NixOS does not provide.
          # Point it at the nixpkgs builds instead and stop it trying.
          PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
        };
   ```

2. Add `playwright-core` as a devDependency in
   `/home/lox/code/_fcl/rookery/search/0.1.0/package.json`. Use `playwright-core`
   and NOT `playwright`: the latter bundles a browser downloader that is useless
   here. Its version must match the `playwright-driver` in nixpkgs — check with
   `nix eval --raw nixpkgs#playwright-driver.version` and pin that exact version,
   not a caret range, because the driver protocol is version-locked to the
   browser builds.

3. Write a self-contained fixture page at
   `/home/lox/code/_fcl/rookery/search/0.1.0/test/fixture/page.html`. It must be
   the markup `#search-modal` actually emits, not an approximation — copy the
   shapes from `/home/lox/code/_fcl/rookery/search/0.1.0/src/ui.typ` lines
   249-312, which emit, in order: the `<script type="application/json">` island,
   the `<button class="rookery-search-trigger" data-rookery-search-modal="...">`,
   and the `<dialog class="rookery-search-modal" data-rookery-search="...">` with
   its `.rookery-search-input`, `.rookery-search-list` and
   `.rookery-search-preview`. Put the trigger and the dialog inside a
   `<header style="position: sticky; top: 0; z-index: 10; display: flex">` — that
   is where a real site places them and it is the arrangement the bug report came
   from. Link `../../src/search.css` and load `../../src/search.js` as
   `<script type="module">`; source mode is how these packages are consumed when
   resolved from a repository ref, so it is the mode worth testing.

   Give the island `data-rookery-search-src="./index.json"` and write a small
   `/home/lox/code/_fcl/rookery/search/0.1.0/test/fixture/index.json` beside it
   holding three or four rows in the island's real shape
   (`{ id, text, href, tags, body }` — read one out of
   `/home/lox/code/_fcl/rookery/search/0.1.0/src/corpus.typ` to get the field
   names exactly right).

4. Write `/home/lox/code/_fcl/rookery/search/0.1.0/test/browser.mjs`. It is a
   plain script rather than a `*.test.mjs` file, deliberately: `just test`'s glob
   is `test/*.test.mjs` and must keep running with no browser present, since that
   is what CI and a bare `node` checkout have. The script must:

   - Serve `test/fixture/` over HTTP on an ephemeral port with node's own
     `http` module. A `file://` origin will not do — ES modules and `fetch` are
     both blocked there, which is a different failure from the one being tested.
   - Loop over `webkit`, `chromium` and `firefox` from `playwright-core`.
   - Fail the process with a non-zero exit code and a named message on the first
     failed assertion, naming the engine.

   Four cases per engine:

   1. **The trigger opens the modal.** Load the page, wait for the index, click
      `.rookery-search-trigger`, assert `dialog.open === true`, assert the
      dialog's `getBoundingClientRect().height > 0`, and assert at least one
      `.rookery-search-row` rendered.
   2. **Escape closes it.** Press `Escape`, assert `dialog.open === false`.
   3. **A touch tap opens it too.** Repeat case 1 in a context created with
      `{ hasTouch: true, isMobile: true, viewport: { width: 820, height: 1180 } }`
      using `.tap()` rather than `.click()`. An iPad was half the bug report.
   4. **A failed index still opens the modal.** Route `**/index.json` to
      `route.abort()`, then click the trigger and assert `dialog.open === true`
      and that the pane reads `Search index unavailable` — the behaviour the
      preceding bird introduces. Assert also that at least one `console` message
      of type `warning` mentioning `@rookery/search` was captured, so a silent
      failure can never come back.

5. Add a recipe to `/home/lox/code/_fcl/rookery/search/0.1.0/Justfile`, beside
   the existing `test` and `parity` ones:

   ```
   # Real-engine smoke tests for #search-modal, across WebKit (the Safari
   # engine), Chromium and Gecko. Needs this package's own devShell for the
   # browser builds; `just test` stays runnable without it.
   browser:
       node test/browser.mjs
   ```

## Non-goals

- Do NOT add this to `/home/lox/code/_fcl/rookery/.github/workflows/check.yml`.
  Wiring suites into CI is the separate bird
  `rk-run-every-package-s-own-suite-in-ci-d0a26188`, which rewrites that file;
  editing it here would conflict with that bird on landing. Say in the report
  that CI wiring is deliberately left to it.
- Do NOT convert the existing linkedom suite to Playwright. The 17 `*.test.mjs`
  files are fast unit tests of pure functions and stay exactly as they are.
- Do NOT add visual or screenshot comparison. Four behavioural assertions per
  engine, no image baselines to maintain.
- Do NOT test `#panel`, `#filter-panel` or `#search-bar`'s dropdown here. This
  suite is about the modal, which is what the bug report was about.
- Do NOT change anything under `src/`.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && nix develop -c just browser`
   exits 0 and prints a pass line for each of `webkit`, `chromium` and `firefox`.
2. Temporarily break it to prove it bites: change the fixture's trigger class
   from `rookery-search-trigger` to `rookery-search-trigger-x`, re-run
   `nix develop -c just browser`, and confirm it exits non-zero naming the
   engine and the case. Restore the class afterwards.
3. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just test` — the existing node
   suite still runs and is still green OUTSIDE the devShell, with no browser
   installed, proving the glob was not widened.
4. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just build` — vite still
   bundles `dist/lib.js`, proving the new fixture files under `test/` were not
   picked up as entry points.