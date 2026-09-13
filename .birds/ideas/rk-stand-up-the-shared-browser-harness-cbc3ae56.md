---
id: rk-stand-up-the-shared-browser-harness-cbc3ae56
short-id: cbc
title: Stand up the shared browser harness
priority: 1
labels:
- test-browser
deps: []
closed: true
---
This repo has no browser testing of any kind. `search`, `todos` and `slipshow`
ship 22 `*.test.mjs` files between them, all running under node with linkedom
standing in for a browser. linkedom is a DOM object graph, not an engine: no
layout, no `getBoundingClientRect`, no `<dialog>`, no top layer, no `fetch`, no
`DOMParser`, no focus model, no CSS cascade, no real event dispatch. Everything
those packages do that is actually browser behaviour is therefore unasserted, and
a Safari bug report against `#search-modal` had to be diagnosed by standing a
Playwright harness up by hand.

This bird files that harness permanently, once, at the repo root. Three suites
are queued behind it — the search modal, the search dropdown and preview pane,
the slipshow edge layer, the todos dependency graph — and each of them is a
fixture plus assertions, not another copy of this plumbing.

THREE ENGINES, and WebKit is the point of the exercise. Playwright's `webkit`
build is the Safari engine, which is the one browser nobody working on this repo
can run natively; Chromium and Firefox come along at no extra cost and catch the
converse mistake.

HOW PLAYWRIGHT IS RESOLVED, and this is the part that is easy to get wrong on
this machine. `playwright-core` normally downloads its own browser binaries,
which are dynamically linked against libraries NixOS does not provide and will
not run. nixpkgs ships both halves — `playwright-driver` IS the `playwright-core`
package (its `package.json` declares `"name": "playwright-core"`), and
`playwright-driver.browsers` is the matching browser set. Taking both from the
same nixpkgs means the driver protocol and the browser builds can never drift
apart, which a pinned npm dependency would eventually do.

VERIFIED WORKING before this bird was written, on this machine, with exactly the
mechanism specified in step 2:

```
webkit OK
chromium OK
firefox OK
```

Note that `NODE_PATH` does NOT work for this: node ignores it for ES modules, and
the harness is an ES module. Importing the store path directly is what works.

Touches: /home/lox/code/_fcl/rookery/flake.nix, /home/lox/code/_fcl/rookery/Justfile, /home/lox/code/_fcl/rookery/test/browser/harness.mjs, /home/lox/code/_fcl/rookery/test/browser/selftest.mjs

## Steps

1. In `/home/lox/code/_fcl/rookery/flake.nix`, add the browsers to the root
   devShell and export the two paths the harness reads. The `buildInputs` list
   currently holds `just`, `nodejs`, `pnpm`, `typst`. Make the devShell:

   ```nix
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            just
            nodejs
            playwright-driver.browsers
            pnpm
            typst
          ];
          # Playwright downloads its own browser binaries by default and those
          # downloads are dynamically linked against libraries NixOS does not
          # provide. Both halves come from nixpkgs instead, from one derivation
          # each, so the driver protocol and the browser builds cannot drift
          # apart the way a pinned npm dependency eventually would.
          # `playwright-driver` IS the playwright-core package — its own
          # package.json declares that name.
          PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
          PLAYWRIGHT_CORE = "${pkgs.playwright-driver}";
        };
   ```

2. Write `/home/lox/code/_fcl/rookery/test/browser/harness.mjs`. It is the only
   file in this repo that knows how to find Playwright or how to serve a
   directory; a suite imports it and writes assertions. It must export exactly
   these four things.

   `loadPlaywright()` — resolves the three engines, preferring the nix store path
   and falling back to an ordinary `node_modules` resolution so the same harness
   works in CI, where there is no nix:

   ```js
   // `PLAYWRIGHT_CORE` is set by the root devShell to the nixpkgs
   // `playwright-driver` derivation, which is the playwright-core package.
   // Imported by absolute path because node ignores NODE_PATH for ES modules.
   // The fallback is for a plain `node_modules` install, which is how CI gets it.
   export const loadPlaywright = async () => {
     const core = process.env.PLAYWRIGHT_CORE;
     return core ? import(`${core}/index.mjs`) : import("playwright-core");
   };
   ```

   `serve(dir)` — an `http` server on an ephemeral port (`listen(0)`), returning
   `{ origin, close }`. Serve `index.html` for a path ending in `/`. Resolve every
   request against `dir` and refuse any resolved path that does not start with
   `dir`, so a `..` cannot escape. Answer 404 with a plain body otherwise. Content
   types must at minimum cover `.html` `text/html`, `.js` `text/javascript`,
   `.mjs` `text/javascript`, `.json` `application/json`, `.css` `text/css`,
   `.svg` `image/svg+xml`, `.png` `image/png`, `.woff2` `font/woff2`, with
   `application/octet-stream` for anything else. A wrong type on `.js` is fatal —
   every engine refuses a module script that is not served as JavaScript — so do
   not leave the JavaScript extensions to the default.

   `requireBuild(path, hint)` — if `path` does not exist, print
   `browser: <path> is missing — run <hint> first` and `process.exit(1)`. Suites
   assert against a real `rheo compile` output rather than a hand-written page,
   and this is what turns a forgotten build into a legible message.

   `run(suiteName, fn)` — the engine loop and the only place a suite touches
   process exit:
   - `const { webkit, chromium, firefox } = await loadPlaywright();`
   - For each of `["webkit", webkit]`, `["chromium", chromium]`,
     `["firefox", firefox]` in that order — WebKit first, because it is the engine
     this repo cannot otherwise run and a failure there should be the first thing
     printed.
   - Launch, create a context, call `await fn({ browser, engine, newPage })` where
     `newPage` creates a page that records every `pageerror` and every `console`
     message of type `error` into an array the suite can read.
   - Catch a thrown assertion, print
     `FAIL <suiteName> [<engine>]: <message>`, close the browser, and
     `process.exit(1)`.
   - On success print `ok <suiteName> [<engine>]`.
   - Close every browser before returning, including on the failure path.

   Keep `run` free of any assertion helper of its own — suites use
   `node:assert/strict`, the same module the existing `*.test.mjs` files use.

3. Write `/home/lox/code/_fcl/rookery/test/browser/selftest.mjs`, so this bird is
   verifiable on its own with no package suite existing yet. It serves a
   directory containing one three-line HTML page written by the script itself
   into a temporary directory, opens it in each engine, and asserts
   `document.title`. Roughly twenty lines. It proves the flake wiring, the
   resolution, the server and the engine loop all work.

4. Add a recipe to `/home/lox/code/_fcl/rookery/Justfile`. Put it after
   `check-versions` and before `bump`:

   ```
   # Real-engine tests, across WebKit (the Safari engine), Chromium and Gecko.
   # One runner per file under a package's `test/browser/`, so a package adds a
   # suite by adding a file and nothing here changes. Needs the root devShell for
   # the browser builds; every `just test` in this repo stays runnable without it.
   #
   # The suites assert against a package's BUILT demo, so run that package's
   # `just check` first — each suite says so by name if the build is missing.
   browser:
       #!/usr/bin/env bash
       set -euo pipefail
       shopt -s nullglob
       found=0
       for f in */*/test/browser/*.mjs; do
           echo "==> $f"
           node "$f"
           found=1
       done
       if [ "$found" -eq 0 ]; then
           echo "browser: no suites yet — nothing to run"
       fi
   ```

   `nullglob` matters: with no suite filed yet the glob must expand to nothing
   rather than to the literal pattern.

## Non-goals

- Do NOT write any package's suite here. This bird ships plumbing and a selftest;
  the search, slipshow and todos suites are separate birds queued behind it.
- Do NOT add a `package.json` at the repo root, and do NOT add `playwright` or
  `playwright-core` as an npm dependency anywhere. Both come from nixpkgs. The
  `node_modules` fallback in `loadPlaywright` is for CI, which is a separate bird
  and will provide it.
- Do NOT touch `.github/workflows/check.yml`. Wiring this into CI is its own
  bird; it needs a browser install step on `ubuntu-latest`, where there is no
  nix.
- Do NOT touch any package's own `flake.nix`, `Justfile` or `package.json`.
  `search/0.1.0` and `slipshow/0.1.0` have devShells of their own for node and
  pnpm; the browsers belong to the root shell, which direnv already supplies
  everywhere in this repo.
- Do NOT add screenshot or visual comparison. No image baselines.
- Do NOT convert any existing `*.test.mjs` file. Those are fast unit tests of
  pure functions and stay exactly as they are.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery && nix develop -c node test/browser/selftest.mjs`
   exits 0 and prints three lines, `ok selftest [webkit]`, `ok selftest
   [chromium]`, `ok selftest [firefox]`, in that order.
2. `cd /home/lox/code/_fcl/rookery && nix develop -c just browser` exits 0. With
   no package suite filed yet it prints `browser: no suites yet — nothing to run`
   — the selftest lives at `test/browser/`, not `*/*/test/browser/`, so the glob
   does not pick it up.
3. Break it to prove it bites: edit `selftest.mjs` to assert a title the page does
   not have, re-run step 1, and confirm it exits non-zero with a line naming
   `webkit`. Restore the assertion afterwards.
4. `cd /home/lox/code/_fcl/rookery && just check-versions` still prints
   `check-versions OK across ...`, proving the new root files were not picked up
   by the version lint.