---
id: rk-run-the-browser-suites-in-ci-32f2e692
short-id: 32f
title: Run the browser suites in CI
priority: 1
labels:
- test-browser
deps:
- blocked-by:rk-stand-up-the-shared-browser-harness-cbc3ae56
- blocked-by:rk-browser-smoke-tests-for-the-search-modal-7e1a2d1b
- blocked-by:rk-browser-tests-for-the-slipshow-deck-9514479d
- blocked-by:rk-browser-tests-for-the-todos-graph-2b7d4c0f
- blocked-by:rk-browser-tests-for-the-search-dropdown-b7dba794
closed: true
---
Once the browser suites exist they run on one person's machine and nowhere else.
This bird makes CI read them, which is the difference between a test suite and a
test suite somebody remembers to run.

`/home/lox/code/_fcl/rookery/.github/workflows/check.yml` is 248 lines,
`runs-on: ubuntu-latest` (line 12), with four unnamed setup steps —
`actions/checkout@v5` (15), `pnpm/action-setup@v5` (17-19),
`actions/setup-node@v5` with node 22 (21-23), `extractions/setup-just@v3` (25) —
then Typst and rheo installs, then seventeen named steps.

THE ONE THING THAT MAKES THIS AWKWARD: **there is no nix in this workflow.** No
`cachix/install-nix-action`, nothing nix-shaped anywhere in the file. Locally the
browser harness gets Playwright from the root devShell, which sets
`PLAYWRIGHT_CORE` and `PLAYWRIGHT_BROWSERS_PATH` from nixpkgs so the driver and
the browser builds can never drift apart. On `ubuntu-latest` neither variable is
set, and the harness's `loadPlaywright` falls back to an ordinary
`node_modules` resolution of `playwright-core` — which is precisely why that
fallback exists. This bird provides the `node_modules` half.

Do NOT add nix to this workflow to avoid that. Installing nix and evaluating the
flake to get three browsers would cost minutes per run, on every push and every
pull request, to reproduce something `npx playwright install` does in seconds with
a cache. The two paths are allowed to differ because the harness already abstracts
over them.

ORDERING IS LOAD-BEARING. Every browser suite asserts against a package's BUILT
demo and exits with a named message if it is missing. The three demos are built by
steps already in this file:

- line 212 — `search rheo demo compiles and asserts` —
  `cd search/0.1.0/demo/rheo && just check`
- line 232 — `todos rheo demo compiles and asserts` — `cd todos/0.1.0 && just check`
- line 239 — `slipshow build, unit fixtures and rheo demo` —
  `cd slipshow/0.1.0 && just build && just test && just test-js && just check`

So the browser step goes at the END of the job, after line 246
(`slipshow examples compile`), and nowhere else.

DEPENDS ON the browser-harness bird (which adds the root `just browser` recipe and
`test/browser/harness.mjs`) and on the three suite birds, because a CI step that
runs zero suites and reports green is worse than no step.

Touches: /home/lox/code/_fcl/rookery/.github/workflows/check.yml

## Steps

1. Pick one Playwright version and use it in both places below. Read it off the
   `playwright-core` npm registry and write the exact version, never a caret
   range: the browser builds `playwright install` downloads are matched to the
   driver protocol of the same version, and a range lets the two drift on a
   future run of an unchanged workflow. Call it `<VERSION>` in the steps below.

2. Add a cache step for the downloaded browsers, immediately before the run step
   in step 3. Playwright installs into `~/.cache/ms-playwright`:

   ```yaml
      - name: Cache Playwright browsers
        uses: actions/cache@v4
        with:
          path: ~/.cache/ms-playwright
          key: playwright-<VERSION>-${{ runner.os }}
   ```

   Keying on the version and the OS and nothing else is correct here: the
   contents depend on exactly those two things, so there is no restore-key
   fallback worth having — a partial hit would leave a mismatched browser set,
   which is worse than a clean download.

3. Add the browser step at the very end of the job, after the existing
   `slipshow examples compile` step at line 246:

   ```yaml
      # Real-engine tests across WebKit (the Safari engine), Chromium and Gecko.
      # LAST in the job, because every suite asserts against a package's BUILT
      # demo and the three demos are built by the steps above.
      #
      # No nix here, unlike the local path: the root devShell hands the harness
      # `PLAYWRIGHT_CORE` and `PLAYWRIGHT_BROWSERS_PATH` from nixpkgs, and
      # `loadPlaywright` falls back to a plain node_modules resolution when
      # neither is set. Installing nix on the runner to reproduce that would cost
      # minutes a run to buy nothing.
      - name: Browser suites across WebKit, Chromium and Gecko
        run: |
          npm install --no-save playwright-core@<VERSION>
          npx --yes playwright@<VERSION> install --with-deps webkit chromium firefox
          just browser
   ```

   `--with-deps` installs the system libraries the browser builds need and
   requires sudo, which `ubuntu-latest` provides. `--no-save` because this repo
   has no root `package.json` and must not grow one for this — the harness needs
   `playwright-core` resolvable from the repo root and nothing more.

4. Add nothing else. In particular do not touch any existing step, and do not
   reorder the file.

## Non-goals

- Do NOT add nix, `cachix/install-nix-action`, or a flake evaluation to this
  workflow. See above; the divergence is deliberate and the harness abstracts it.
- Do NOT add a root `package.json`. `npm install --no-save` is what keeps this to
  one step and no tracked file.
- Do NOT split the browser suites across a matrix of jobs. Three engines over a
  handful of pages is seconds of work; a matrix would re-run every Typst and rheo
  install above it three times.
- Do NOT make this step `continue-on-error`. A failing browser suite must fail the
  check, which is the entire point of adding it.
- Do NOT change `/home/lox/code/_fcl/rookery/Justfile`, the harness, or any
  package's suite. If `just browser` needs a flag to work in CI, that is a defect
  in the harness bird and should be reported rather than patched around here.
- Do NOT remove or weaken any existing assertion, including
  `demo/rheo/check.sh`'s CSS greps, on the grounds that a browser suite now covers
  them better.

## VERIFY

1. Read `/home/lox/code/_fcl/rookery/.github/workflows/check.yml` and confirm the
   new steps are the LAST two in the `steps:` list, after
   `slipshow examples compile`.
2. Confirm the same exact version string appears in the cache key, the
   `playwright-core@` install and the `playwright@` install, and that none of the
   three carries a `^` or `~`.
3. `cd /home/lox/code/_fcl/rookery && just check-versions` still prints
   `check-versions OK across ...` — that recipe reads this workflow file, so a
   malformed edit shows up there.
4. Locally, prove the command the step runs actually works from a clean
   node_modules state:
   `cd /home/lox/code/_fcl/rookery && env -u PLAYWRIGHT_CORE -u PLAYWRIGHT_BROWSERS_PATH just browser`
   should FAIL with a resolution error for `playwright-core`, confirming the
   fallback path is the one CI exercises and that it is not silently reading the
   nix store. Then re-run plain `nix develop -c just browser` and confirm it
   passes again.
5. Push the branch and confirm the `Check` workflow's new step runs and prints an
   `ok <suite> [webkit]` line for each filed suite. This is the one VERIFY step
   that needs the remote; everything above is local.