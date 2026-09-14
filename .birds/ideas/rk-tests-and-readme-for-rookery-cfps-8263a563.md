---
id: rk-tests-and-readme-for-rookery-cfps-8263a563
short-id: '82'
title: Tests and readme for @rookery/cfps
priority: 2
labels:
- feat-cfps-package
deps:
- blocked-by:rk-scaffold-rookery-cfps-package-260c3227
- blocked-by:rk-port-cfps-rounds-table-panel-css-e7a8ee7a
closed: true
---
## What this is

Depends on `cfps-scaffold` and `cfps-panel-css` (both must have landed: the
package `/home/lox/code/_fcl/rookery/cfps/0.1.0/` already has `src/cfp.typ`
(the `cfps(kinds:)` factory, returning `venue`/`cfp`/`cfp-state`) and
`src/panel.typ` (the same factory also returning `panel`) plus `src/cfps.css`).
This bird replaces the throwaway `test/smoke.typ` those two birds wrote with a
real test suite in the shape every other pure-Typst package here uses, and
writes the package's `readme.md`.

## Reference test shape to copy

`/home/lox/code/_fcl/rookery/meetings/0.1.0/test/` (read every file in it —
it is the smallest complete example of the pattern this package's tests
should follow) and `/home/lox/code/_fcl/rookery/meetings/0.1.0/Justfile`'s
`test:` recipe, already quoted in `cfps-scaffold`'s own bird:

```
test:
    mkdir -p test/build
    typst compile --features html --root . --format html test/units.typ test/build/units.html
    @echo "units OK"
    typst compile --features html --root . --format html test/view.typ test/build/view.html
    ./test/check.sh
```

Two fixtures, the same split meetings uses and the split this package
should copy:

- `test/units.typ` asserts every VALUE the package's constructors derive —
  tags, dates, titles, ladder-driven state — using plain `assert.eq`, no
  HTML involved. This is where `cfp-state`/`real-stage-of`'s four-state
  logic gets exercised directly against hand-built tag dictionaries, and
  where `venue`/`cfp`'s tag-construction (the `own` dictionary each builds)
  gets checked field by field.
- `test/view.typ` plus `test/check.sh` assert the MARKUP — that `#cfp`'s own
  in-body rail renders `deadline`/`scheduled`/every `timeline:` stage
  together as one chronological sequence (it renders whenever ANY of the
  three is given, not only `timeline:`), that the `_opportunity-table` header
  (`Work` for a cfp, `Call` for a venue) lands below the title and above that
  rail, that a venue backlink (`ref(label("idea:" + venue))`) is present when
  `venue:` was given and absent when it was not, and that `panel(..)`'s rows
  carry the right CSS classes for a settled vs. an open vs. an unanswered
  call.
  `test/check.sh` is a shell script that greps the compiled
  `test/build/view.html` for expected substrings and exits non-zero on a
  miss — write it in that shape (copy `meetings/0.1.0/test/check.sh`'s
  actual structure, do not invent a different one).

Replace `cfps-scaffold`'s `test/smoke.typ` and `cfps-panel-css`'s additions
to it with this pair once the pair covers everything smoke.typ covered —
delete `test/smoke.typ` at the end rather than leaving both.

Update the `Justfile`'s `test:` recipe to the two-fixture form above (it
currently only compiles `test/smoke.typ`).

## What to test — the specific things that must NOT regress

These came from real bugs found migrating the reference site onto this same
logic; each is worth its own assertion in `test/units.typ` rather than being
folded into a bigger one:

1. **A lapsed, unanswered call reads as `"open"`, never `"in-flight"`.**
   Build a cfp-shaped tags dictionary with only a `deadline:` in the past
   and no `timeline:`, call `cfp-state(tags, ladder: <any>, today: <a date
   after the deadline>)`, assert it returns `"open"`. (Reading the RAW,
   unfiltered log — the bug this package's `cfp-state` exists to avoid —
   would return `"in-flight"` here, since the deadline is the latest
   "reached" entry and is not a member of any ladder's terminal list.)
2. **A stage dated BEFORE the deadline is still detected.** Build a tags
   dictionary with `deadline:` on, say, day 10, and a `timeline: (dropped:
   day 5)` — a real answer given chronologically before the wire even
   arrived. Call `real-stage-of(tags, today: day 15)`, assert it returns
   `"dropped"`, not `"deadline"`. (Raw `stage-of` picks whichever entry is
   chronologically LATEST among those already past — here, the deadline
   itself, at day 10 — which would silently mask the real answer.)
3. **`venue:` is optional on `cfp(..)`** — a cfp naming no venue still
   builds successfully and its title falls back to the id/`title:` form
   with no crash reading a `none`.
4. **`kind:` outside the caller's `kinds:` dictionary fails loudly.** Assert
   that calling `cfp(.., kind: "not-a-real-kind")` raises (Typst's
   `assert`) with a message naming the valid kinds, not a silent `none`
   ladder that later renders every row as permanently in-flight.
5. **Every stage in every configured kind's ladder is standardized, not
   just the two or three used elsewhere in this suite.** Build a `kinds:`
   dictionary covering at least two kinds with DIFFERENT ladders (mirror
   the reference's own job/journal/conference split — a family rung like
   `review-*` in one of them), and for EVERY name in EVERY kind's
   `transit`/`terminal` arrays (expanding a `-*` family rung to a concrete
   instance, e.g. `review-1`), mint a `#cfp` whose `timeline:` uses that one
   stage, and assert (a) it does not raise (confirms the `stage in STAGES`
   check accepts every ladder-declared name, not only the ones this test
   file happens to reach for elsewhere) and (b) `cfp-state(..)` returns
   `"in-flight"` for a transit stage or `"settled"` for a terminal one, per
   which array it came from. This is the test that catches a stage falling
   through to some OTHER rendering path instead of `@rookery/timeline`'s —
   see `cfps-scaffold`'s "Every stage goes through @rookery/timeline, and
   only through it" for why this invariant matters and what it would look
   like to violate it by accident (a per-kind flat tag, a bespoke `outcome:`
   argument, anything that records a stage somewhere other than the shared
   log).
6. **Closing is real, not a flag.** Mint a `#cfp` with a `timeline:` that
   reaches a terminal stage (e.g. `offered`), and separately one that is
   merely lapsed (a past `deadline:`, no `timeline:` at all). For both,
   assert `has-stage(tags, CLOSED-STAGE)` — imported from
   `@rookery/timeline` — is `true` on the minted note's own tags. This is
   the exact bug `wl-close-cfp-through-rookery-todos-not-a-71011bf4` (filed
   in `waterline/rookery`'s own tracker) found in the reference
   implementation: a `#cfp` that marks itself closed with a flat boolean
   tag rather than a real dated log entry never satisfies
   `@rookery/todos`' own `is-closed`, so it shows up forever in a
   consumer's `today-panel`/`todo-table`. This package's `cfp` must not
   repeat that mistake — see `cfps-scaffold`'s "Design change 2".

## `readme.md`

Write it in the shape `meetings/0.1.0/readme.md` and
`todos/0.1.0/readme.md` use (skim both for structure — a short "what this
is" opening, a usage example, then a reference section per exported name).
Cover, specifically:

- The two-note-family collapse this package encodes: a call and what
  happened when it was answered are ONE note (`#cfp`), not two — state a
  reader why (a call and its answer are never two different attempts at two
  different things), briefly, in your own words rather than copying
  waterline's own comments verbatim.
- The `cfps(kinds:)` factory and its `kinds:` shape (`kind name -> (sort:
  <string>, ladder: (transit: (..), terminal: (..)))`), with a full worked
  example a reader can copy — mint a `venue`, mint a `cfp` naming it with a
  `deadline:`, mint a second `cfp` with a `timeline:` reaching a terminal
  stage, call `panel(state: "settled")` and show it picking up the second
  one only.
- Why `kind`/`ladder` are caller-supplied rather than owned by the package —
  one short paragraph, pointing at `@rookery/timeline`'s own `ladder.typ`
  header comment as the precedent, not restating that comment's argument at
  length.
- `#cfp` IS an `#todo` — built on `@rookery/todos`' own `todo(..)`, not a
  bare `tagged-idea`. State plainly what this buys a reader for free: a cfp
  shows up in `today-panel`/`todo-table` and closes correctly the moment it
  is answered or its deadline lapses, with no separate wiring, and its
  `priority:` is `@rookery/todos`' own — a consumer already running that
  package's worklists gets cfps in them automatically.
- A short "integrating `#window`" note: if a consuming site wraps
  `@rookery/todos`' `#window` with its own hiding logic (e.g. hiding a
  transcluded cfp whose real answer was negative), that wrapper must pass
  `closed: true` through on whatever branch decides to SHOW the note — the
  todos package's own base `#window` independently hides any closed-todo
  note unless told otherwise, and every `#cfp` now closes its own todo on
  either a lapsed deadline or a real answer, so a site's own hiding
  decision will otherwise be overridden by that second, unrelated check.
  This is not this package's own bug to fix (it lives in how a consumer's
  site-level `#window` wrapper composes with `@rookery/todos`), but every
  consumer will hit it the first time they wrap `#window` around a `#cfp`,
  so it belongs in the readme rather than being rediscovered per project.

## Non-goals

- Do NOT touch `/home/lox/code/waterline/rookery` — not even to verify
  against it. This package's own test suite is the verification surface.
- Do NOT add a `demo/` directory — nice to have, not required; if there is
  time left over after the steps above, note it as a suggestion in the
  readme's own "future work" rather than building it as part of this bird.

Touches: cfps/0.1.0/Justfile, cfps/0.1.0/readme.md, cfps/0.1.0/test/units.typ, cfps/0.1.0/test/view.typ, cfps/0.1.0/test/check.sh

## VERIFY

```
cd /home/lox/code/_fcl/rookery/cfps/0.1.0
just test
```
must print `units OK`, then run `check.sh` to completion with exit code 0
(the fixture script itself prints what it checked — confirm the shell exit
code with `echo $?` immediately after, since a script that prints "ok" but
exits non-zero on one bad line is easy to miss by eye alone). Then, from the
repo root:
```
cd /home/lox/code/_fcl/rookery
just build
```
must still succeed, and `test/smoke.typ` must no longer exist
(`ls cfps/0.1.0/test/` should list only `units.typ`, `view.typ`,
`check.sh`, and the gitignored `build/`).