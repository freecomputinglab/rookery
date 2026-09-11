---
id: rk-check-meetings-in-ci-db3493eb
short-id: db
title: Check meetings in CI
priority: 2
labels:
- ci-meetings
deps:
- blocked-by:rk-add-the-meetings-package-4a1ea2fb
closed: true
---
Add a CI step for `@rookery/meetings` to
`/home/lox/code/_fcl/rookery/.github/workflows/check.yml`, so the package's two
fixtures run on every push and pull request.

**Prerequisite, already satisfied when this bird is startable.** The bird this one
is blocked by creates `meetings/0.1.0/` with a `Justfile` whose `test` recipe
compiles `test/units.typ` and `test/view.typ` and then runs `test/check.sh`.

**Why a step is needed at all.** `check.yml` does NOT discover packages: it names
each one explicitly (`core unit fixture`, `timeline unit and view fixtures`,
`search build and parity`, `todos build, unit fixture and graph tests`, and so on).
A package with no step is a package whose tests never run in CI. The
`publish-packages.yml` workflow and the repo-root `Justfile` DO walk `*/*/`
themselves and need no edit — do not touch either.

## Where the step goes, and why exactly there

`check.yml` has a step named `Resolve the @rookery namespace from this checkout`
which symlinks the whole checkout to `$XDG_CACHE_HOME/typst/packages/rookery`.
`meetings/0.1.0/src/lib.typ` imports `@rookery/core:0.1.0` and
`@rookery/timeline:0.1.0` BY COORDINATE, so its fixtures cannot resolve before
that step runs — put the new step AFTER it. The natural home is immediately after
the existing `timeline unit and view fixtures` step (`cd timeline/0.1.0 && just
test`), because this package sits on top of that one and its fixtures are the same
shape.

## Steps

1. Open `/home/lox/code/_fcl/rookery/.github/workflows/check.yml` and find the
   step whose `name:` is `timeline unit and view fixtures`.
2. Insert a new step directly after it, matching the file's existing style — a
   comment block above the step saying what it covers and why it sits where it
   does, then the step itself:

   ```yaml
         # AFTER the namespace-symlink step, like every step that resolves a
         # package by coordinate: @rookery/meetings imports BOTH
         # `@rookery/core:0.1.0` and `@rookery/timeline:0.1.0`. Buildless like
         # those two, so no vite step.
         #
         # `just test` here runs TWO fixtures: `test/units.typ` asserts the values
         # `#meeting` derives — the `occurred` log entry, the `created` date `on:`
         # sets, the synthesized title — and `test/view.typ` plus `test/check.sh`
         # assert the markup, including that the record and the rail come ABOVE the
         # note's prose, which is document order and so invisible to the value
         # fixture.
         - name: meetings unit and view fixtures
           run: cd meetings/0.1.0 && just test
   ```

3. Indentation: two spaces deeper than `steps:`, i.e. the `- name:` lines in this
   file are indented by six spaces. Copy the surrounding steps exactly rather than
   trusting this bird's own quoting.

## Do NOT

- Do NOT add a step to `.github/workflows/publish-packages.yml`. It already walks
  `*/*/typst.toml` and handles a package with no `package.json` by shipping `src/`
  directly, which is exactly what this package wants.
- Do NOT edit the repo-root `Justfile`. Its `build` recipe finds every nested
  `Justfile` itself, and `check-versions` walks `*/*/typst.toml`.
- Do NOT bump the pinned Typst or rheo versions in `check.yml`, and do not touch
  the digest in the rheo install step.
- Do NOT add a rheo demo step. This package has no demo project.
- Do NOT reorder or rename existing steps.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery && python3 -c "import yaml,sys;
   d=yaml.safe_load(open('.github/workflows/check.yml'));
   names=[s.get('name') for s in d['jobs']['check']['steps']];
   print(names); assert 'meetings unit and view fixtures' in names"` — prints the
   step list including the new name and exits 0. This is the assertion that the
   file still parses as YAML, which is the failure mode a hand-edited workflow
   has. If `yaml` is not importable, fall back to
   `grep -n "meetings unit and view fixtures" -A 1 .github/workflows/check.yml`
   and check by eye that the `run:` line reads
   `cd meetings/0.1.0 && just test` and that its indentation matches the step
   above it.
2. The new step appears AFTER the step named `Resolve the @rookery namespace from
   this checkout` in that same list — confirm by index, not by eye.
3. `cd meetings/0.1.0 && just test` locally — the command the step runs is green.