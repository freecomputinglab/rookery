---
id: rk-keep-a-replayed-nested-note-from-taking-d4fc76cb
short-id: d4f
title: Keep a replayed nested note from taking a second ordinal
priority: 5
labels:
- fix-scope-ordinal-replay
- parked
deps: []
closed: false
---
Touches: core/0.1.0/src/state.typ, core/0.1.0/src/idea.typ, core/0.1.0/demo/rheo/content/nested-replay.typ, core/0.1.0/demo/rheo/check.sh

A titleless note nested inside another note takes its number from a container
ordinal that advances every time the parent's body is rendered. Transclude the
parent and the child takes a second number, so one note has two ids depending
on where it was reached.

## The defect, measured

`/home/lox/code/waterline/rookery/clusters/digitaltheory/pragma/meetings.typ`
lines 376 to 419 are one `#meeting` call, and its body contains **exactly one**
nested `#idea[` (line 398). Confirm before starting:

```
awk 'NR>=376 && NR<=419' /home/lox/code/waterline/rookery/clusters/digitaltheory/pragma/meetings.typ | grep -c '#idea'
```

printed `1`. Yet building that site shows, in the non-convergence trace for
`state("rookery-idea-scope")`, a final run containing both of:

```
(key: "meeting-with-on-4-9-26",   n: 2),
(key: "meeting-with-on-4-9-26-2", n: 0),
```

The first is the meeting's own pushed container, reporting that **two**
titleless notes have been minted inside it. The second is a container pushed
for a note whose id is `meeting-with-on-4-9-26-2` — the same single nested
note, minted again, taking ordinal 2 instead of the 1 it already had.

A nested note's id is `<parent id>-<n>`, so an ordinal that advances on replay
is an id that changes with it. This is not the title-slug numbering: that is a
separate mechanism, and `state("rookery-idea-slug-count")` never appears in a
non-convergence warning on this site at all.

## Why it happens

Anchors, run at filing from `/home/lox/code/_fcl/rookery/core/0.1.0`:

```
rg -n 'let _scope-peek|let _scope-record|let _scope =' src/state.typ
```

printed `src/state.typ:395` (`_scope`), `:415` (`_scope-peek`), `:451`
(`_scope-record`). And:

```
rg -n '_scope-record\(|_scope-peek\(|_scope.update' src/idea.typ
```

printed five sites: `:167-168` (the excluded-note path, which still consumes an
ordinal to keep sibling numbering stable), `:276` (the container peek in the
main mint), `:310` (the record), `:331` (this note's OWN container pushed for
its body's nested notes) and `:634` (the matching pop).

`_scope-record` advances the ordinal unconditionally. When `#window` replays a
parent note's body, the nested `#idea` mint block runs again, records again,
and the container it is counting against goes from 1 to 2.

## The fix, and the model to copy

This exact problem was already solved for the title-slug numbering in this same
file. Anchors:

```
rg -n 'let _slug-count =|let _slug-peek|let _slug-record' src/state.typ
rg -n 'let occupant' src/idea.typ
```

printed `src/state.typ:494, :517, :535` and `src/idea.typ:289`. There,
`_slug-count` maps a slug to an ARRAY OF OCCUPANTS rather than a count, an
occupant being the note's own `(title, body, tags, level, display)` tuple built
from call-site values; `_slug-peek` returns an occupant's existing position if
it is already listed, and `_slug-record` appends only when it is absent. A note
rendered twice therefore gets the same number back.

Apply the same shape to the container ordinal: a note that has already taken an
ordinal within a container must get that ordinal back, not the next one. The
occupant tuple is already computed at `idea.typ:289`, before the id exists, so
it is available at the peek and record sites without new plumbing.

Two constraints on the implementation:

1. **Keep the updater a pure function of its own argument.** `_scope-record`
   already follows this, and it is load-bearing: an updater closing over a
   separately-read value was measured to cost one extra compile attempt per
   note sharing the container.
2. **Do not change the top-level (vertebra) accumulator's behaviour** beyond
   making it idempotent the same way. Its keying by handle, its `top: true`
   marker and its per-vertebra reset are correct and were expensive to get
   right.

## Non-goals

- **Do not touch the slug numbering** (`_slug-count`, `_slug-peek`,
  `_slug-record`). It is already idempotent and already stable on this site.
- **Do not touch `bib.typ`.** Its footnote counters are a separate defect with
  its own bird.
- **Do not touch `urls.typ`, `outline.typ`, `permalink.typ` or `.marrow.typ`.**
- **Do not reach for `state("rheo-handle")` or any rheo state** in the
  identity. This package must keep working under a plain `typst compile`, which
  `demo/pure/` exercises.
- **Do not edit anything in `/home/lox/code/waterline`.** You may READ it and
  BUILD it as a diagnostic (VERIFY 4), nothing more.

## Uncertainty, and what is known about reproducing it

A previous investigation could NOT reproduce this at small scale: a solo
`#meeting`, a `#meeting` transcluded cross-vertebra, the same content value
placed twice, two argument-identical calls, and a verbatim copy of the entire
real `pragma/meetings.typ` all converged cleanly with a single occupant. The
defect has so far only been observed on the full site.

So do not assume a two-file fixture will reproduce it. Write the fixture
anyway (VERIFY 2) — a nested titleless note inside a parent that is
transcluded is the minimal shape of the bug, and it is the regression test
whether or not it fails today. If it does NOT fail before your change, say so
explicitly in your report and rely on the site measurement in VERIFY 4 for
evidence that the fix does something.

If you find the ordinal cannot be made idempotent without an identity that is
itself unstable, STOP and report with your evidence rather than landing a
guess.

## VERIFY

1. From `core/0.1.0/`, `just test` passes.
2. Add `core/0.1.0/demo/rheo/content/nested-replay.typ`: a titled parent note
   containing one titleless nested note with a distinctive grep marker, and
   transclude that parent into a `#window` on a different vertebra (the demo
   already does this elsewhere — see `demo/rheo/content/sub/page.typ` for the
   shape). Assert in `check.sh` that the nested note mints exactly one page,
   that its name ends `-1`, and that no page ending `-2` exists for it.
3. From `core/0.1.0/demo/rheo/`, `just check` passes and prints `demo/rheo OK`.
4. Build the site as a diagnostic: copy
   `/home/lox/code/waterline/rookery/rheo.toml` to a scratch config INSIDE that
   repository (e.g. `rookery/.checkscope.toml`), replace the `repo =`/`branch =`
   pair in `[packages.rookery]` with `path = "<your flight path>"`, run
   `rheo compile rookery --config rookery/.checkscope.toml --html --build-dir <a scratchpad dir> --input today=2026-09-20`,
   and DELETE the scratch config afterwards. In that build's
   `state("rookery-idea-scope")` trace, no key `meeting-with-on-4-9-26-2` may
   appear. Report the trace either way; the document may still fail to converge
   for the footnote reason, which is acceptable.
5. From `core/0.1.0/demo/pure/`, `just build` prints `demo/pure OK`.
6. From the repository root, `just check-versions` still prints its OK line.