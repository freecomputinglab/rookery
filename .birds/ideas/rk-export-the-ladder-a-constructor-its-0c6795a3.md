---
id: rk-export-the-ladder-a-constructor-its-0c6795a3
short-id: 0c67
title: 'Export the ladder: a constructor, its assert and its match rule'
priority: 4
labels:
- chore-timeline-api
deps: []
closed: true
---
A ladder is a public data type of `@rookery/timeline` — `is-settled`, `rung`,
`next-stage` and `#timeline-view` all take one as a `ladder:` parameter — but
everything that operates on one is private. So consumers copy it. `@rookery/cfps`
carries two copies today, and its own comments admit both:

- `/home/lox/code/_fcl/rookery/cfps/0.1.0/src/cfp.typ:123-156` reimplements
  `_assert-ladder` (`timeline/0.1.0/src/ladder.typ:64`), assert messages and all,
  to validate a `kinds:` dictionary whose every value carries a ladder.
- `/home/lox/code/_fcl/rookery/cfps/0.1.0/src/cfp.typ:167-177` reimplements the
  family-pattern match rule as `_stage-in`, with the comment "A local copy rather
  than an import: that rule is private there too".

Three copies of this package's own semantics living outside it is the thing this
package exists to prevent. `ladder.typ:24-27` also states that a ladder is
validated on EVERY call "because a ladder is a plain dictionary a caller writes
inline and there is no constructor to hang the check on" — so give it one, in the
idiom `@rookery/core` already uses: `tag-index(spec)`
(`core/0.1.0/src/data.typ:137`) validates its spec once at construction and
returns a plain dictionary.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/ladder.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/readme.md
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/test/units.typ
Touches: /home/lox/code/_fcl/rookery/cfps/0.1.0/src/cfp.typ

## The three names to export

```typ
// Validated once, returns the plain dictionary every `ladder:` argument takes.
#let stage-ladder(transit: (), terminal: ()) = { ..; (transit: transit, terminal: terminal) }

// For a caller who built one by hand, or holds one inside a larger config.
#let assert-ladder(ladder) = ..

// The family-pattern rule: `stage-matches("review-*", "review-1")` is true,
// `stage-matches("review-*", "reviewer")` is false.
#let stage-matches(pattern, stage) = ..
```

`stage-ladder`, NOT `ladder`. Every function that takes one has a `ladder:`
parameter, and a parameter and a module-level function of the same name cannot
both be reachable by that name inside a function body — that collision already
cost this repo two aliased imports over `countdown` (see
`timeline/0.1.0/src/upcoming.typ:49` and `todos/0.1.0/src/table.typ:32-36`).
Do not reintroduce it here.

## Steps

1. In `timeline/0.1.0/src/ladder.typ`, rename `_assert-ladder` (line 64) to
   `assert-ladder` and `_matches` (line 60) to `stage-matches`. Update the three
   internal callers — `is-settled` (103), `rung` (121), `next-stage` (136) — and
   `_assert-ladder`'s own overlap check, which calls `_matches`.
2. `_is-family` (47) and `_family-prefix` (51) stay PRIVATE: they are how
   `stage-matches` is implemented, not a second public way to ask the same
   question. `rung-name` (56) is already public and keeps its name.
3. Add `stage-ladder(transit: (), terminal: ())` to the same file, after the
   assert. It calls `assert-ladder` on the dictionary it is about to return, so
   there is one set of checks rather than two.
4. `is-settled`/`rung`/`next-stage` keep calling `assert-ladder` — a ladder is
   still a plain dictionary a caller may write inline, and the constructor is an
   option rather than a gate. Say that in one line where the assert is, replacing
   the "there is no constructor to hang the check on" sentence at lines 24-27,
   which will no longer be true.
5. In `cfps/0.1.0/src/cfp.typ`, import `assert-ladder` and `stage-matches` from
   `@rookery/timeline:0.1.0` and delete both local copies:
   - the per-kind ladder checks at lines 145-156 become one
     `assert-ladder(spec.ladder)` call, keeping cfps' own message prefix for the
     things that are ITS contract (that `kinds:` is a dictionary, that each value
     has `sort:` and `ladder:` — lines 129-143 stay);
   - `_stage-in(stage, patterns)` (line 175) becomes
     `patterns.any(p => stage-matches(p, stage))` at its call sites, or a one-line
     local shim if there are several.
6. Add unit assertions to `timeline/0.1.0/test/units.typ`: `stage-ladder` returns
   the dictionary it was given, `stage-ladder` with a rung in both arrays panics,
   `stage-matches("review-*", "review-12")` is true, and
   `stage-matches("review-*", "reviewer")` is false.
7. Document the three in `timeline/0.1.0/readme.md`, in the section that already
   describes what a ladder is, and show `ladder: stage-ladder(..)` in the first
   ladder example.

## Non-goals

- **Do not change what a ladder IS.** Still `(transit: (..), terminal: (..))`,
  still validated the same way, still passed as `ladder:`. This bird exports the
  operations, it does not redesign the type.
- **Do not make `stage-ladder` mandatory.** An inline dictionary must keep
  working; several tests and `cfps`' own `kinds:` config write one.
- **No change to `is-settled`/`rung`/`next-stage`/`rung-name` signatures.**
- **Do not touch `_norm-tags`** — a separate bird exports that one.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test` — prints
   `units OK` then `views OK`.
2. `cd /home/lox/code/_fcl/rookery/cfps/0.1.0 && just test` — prints `units OK`
   and its view check passes.
3. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check` passes (todos builds
   its own `TODO-LADDER` and calls all three ladder functions).
4. `rg -n '_stage-in|transit.*must be an array' /home/lox/code/_fcl/rookery/cfps`
   returns nothing — both copies are gone.
5. `cd /home/lox/code/_fcl/rookery && just check-versions` passes.