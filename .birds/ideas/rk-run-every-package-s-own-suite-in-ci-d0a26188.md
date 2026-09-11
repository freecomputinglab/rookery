---
id: rk-run-every-package-s-own-suite-in-ci-d0a26188
short-id: d0
title: Run every package's own suite in CI
priority: 4
labels:
- chore-ci
deps: []
closed: false
---
Three suites in this repo never run in CI: `bibtex` has no step at all, and the
node test suites of `search` and `slipshow` — 123 cases and 3 files respectively
— are not invoked. Every one of them is green locally today, so this is coverage
that exists and is not being read.

Touches: /home/lox/code/_fcl/rookery/.github/workflows/check.yml

## What is wrong

`/home/lox/code/_fcl/rookery/.github/workflows/check.yml` names its steps
explicitly, one or more per package. The full list of `- name:` steps today:

```
Install Typst 0.15.1
Install rheo 0.6.2 (the declared min_version floor)
Package specs agree with their manifests
core unit fixture
Resolve the @rookery namespace from this checkout
timeline unit and view fixtures
meetings unit and view fixtures
search build and parity
core pure demo compiles and checks, HTML and PDF
core rheo demo compiles and asserts, under the declared floor
core rheo demo's rookery compiles and asserts without rheo too
search rheo demo compiles and asserts
todos build, unit fixture and graph tests
todos rheo demo compiles and asserts
slipshow build, unit fixture and rheo demo
slipshow examples compile
```

Three gaps in that list:

1. **`bibtex` appears nowhere.** `grep -n bibtex .github/workflows/check.yml`
   returns nothing. The package has a real suite —
   `/home/lox/code/_fcl/rookery/bibtex/0.1.0/Justfile`'s `test` recipe compiles
   `test/units.typ` and `test/large.typ` as PDF and four HTML fixtures
   (`sweep.typ`, `sweep-existing.typ`, `sweep-all.typ`, `fields.typ`), echoing
   each one's stderr because the warnings are part of what those fixtures
   assert — and none of it runs on a push.
2. **`search`'s node suite never runs.** Its step is
   `cd search/0.1.0 && just build && just parity`. `just parity` is the
   cross-language fixture; the 123-case node suite is a SEPARATE recipe,
   `just test` (`node --test test/*.test.mjs`), covering the panels, the island,
   the URL state, the selection model, the row builder and the note extractor.
   Compare the `todos` step, which does run `just test-js`.
3. **`slipshow`'s node suite never runs.** Its step is
   `cd slipshow/0.1.0 && just build && just test && just check`. In that package
   `just test` is the TYPST fixture; the JavaScript lives behind `just test-js`
   (`test/camera.test.mjs`, `test/reveal.test.mjs`, `test/edges.test.mjs`).

Note the two packages use the two recipe names the opposite way round from each
other's expectations, which is how both gaps survived: in `search`, `just test`
is the node suite and `just parity` is the Typst-crossing one; in `slipshow` and
`todos`, `just test` is Typst and `just test-js` is node.

All of it is green right now. Confirmed by running each locally:
`search`'s `just test` reports `pass 123` / `fail 0`, `slipshow`'s `just test-js`
passes, and `bibtex`'s `just test` passes.

Line numbers are deliberately not given for the steps — the file is commented
heavily between them, so match the step names quoted above.

## Decisions already made — do not re-derive

- **Add steps; do not restructure the workflow.** It is a deliberately explicit
  list with a long comment above most steps explaining what that step proves and
  why it sits where it does. A matrix over `*/0.1.0` would delete that, and the
  ordering is load-bearing: the `Resolve the @rookery namespace from this
  checkout` step must precede every step whose package imports another by
  coordinate.
- **`bibtex` goes after the namespace-resolution step**, for that reason: its
  `src/lib.typ` builds `#citation` notes over `@rookery/core`, so
  `@rookery/core:0.1.0` has to resolve from the Typst package cache before its
  fixtures compile. Put it beside the `meetings` step, which is there for the
  same reason and is the closest analogue — buildless, no vite, one `just test`.
- **Extend the two existing steps rather than adding new ones** for `search` and
  `slipshow`. One step per package per concern is the file's shape, and
  `build`/`test`/`parity` are one concern: "this package's own suites pass".
- **`bibtex` needs no build step.** It is pure Typst — no `package.json`, no
  `pnpm`, no `dist/` — so `just test` is the whole of it.

## Steps

1. In `/home/lox/code/_fcl/rookery/.github/workflows/check.yml`, change the
   `search build and parity` step to run the node suite as well:

   ```yaml
      - name: search build, unit suite and parity
        run: cd search/0.1.0 && just build && just test && just parity
   ```

   Add a sentence to that step's comment saying that `just test` is this
   package's node suite while `just parity` is the cross-language fixture, and
   that both are needed — the two recipes answer different questions.

2. Change the `slipshow build, unit fixture and rheo demo` step to run its node
   suite too:

   ```yaml
      - name: slipshow build, unit fixtures and rheo demo
        run: cd slipshow/0.1.0 && just build && just test && just test-js && just check
   ```

3. Add a `bibtex` step immediately after the `meetings unit and view fixtures`
   step:

   ```yaml
      # bibtex is buildless like meetings — pure Typst, no vite — and imports
      # `@rookery/core:0.1.0` for the notes its `#citation` constructor builds,
      # so it sits after the namespace-resolution step above. Its recipe compiles
      # two PDF fixtures and four HTML ones, echoing each one's stderr: the sweep
      # fixtures assert on the WARNINGS a sweep emits, so the output is the test.
      - name: bibtex unit and sweep fixtures
        run: cd bibtex/0.1.0 && just test
   ```

4. Check whether `slipshow`'s own panic suite is reachable from a recipe. It is
   `/home/lox/code/_fcl/rookery/slipshow/0.1.0/test/panics.sh` plus thirteen
   `test/panic-*.typ` files, each of which must FAIL to compile with a particular
   message. If no `Justfile` recipe runs it, say so in your flight report and do
   NOT add it here — a shell script asserting on compile failures is its own bird
   with its own verification, and guessing at how it wants to be invoked in CI is
   how a green build starts lying.

## Do NOT

- Do not change any existing step's command other than the two extensions in
  steps 1 and 2.
- Do not replace the explicit step list with a matrix or a loop.
- Do not touch any `Justfile`, any test file, or any package source. If a suite
  fails once CI runs it, that is a finding to report, not a test to edit.
- Do not add a step for the repo-root `just build` or `just check-versions` —
  `Package specs agree with their manifests` already covers the second.
- Do not bump the pinned Typst or rheo versions.

## VERIFY

CI itself cannot be run locally, so verify the commands the new steps invoke, in
the same order CI would, from a clean checkout state:

```sh
cd /home/lox/code/_fcl/rookery/bibtex/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/search/0.1.0 && just build && just test && just parity
cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just build && just test && just test-js && just check
```

Expected: `bibtex`'s recipe completes, echoing its fixtures' stderr; `search`
reports `pass 123` / `fail 0` from `just test` and six `OK` lines from
`just parity`; `slipshow` completes its Typst fixture, its node suite and its
rheo demo. All three are green today, so a failure here is either a real
regression or a wrongly transcribed command.

Then check the workflow file is still valid YAML and the steps read as intended:

```sh
cd /home/lox/code/_fcl/rookery && grep -n "^      - name:" .github/workflows/check.yml
```

Expected: the same list as in this description plus one new `bibtex` entry, with
the `search` and `slipshow` entries renamed as in steps 1 and 2.