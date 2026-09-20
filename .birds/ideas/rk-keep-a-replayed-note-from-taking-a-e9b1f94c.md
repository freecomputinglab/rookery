---
id: rk-keep-a-replayed-note-from-taking-a-e9b1f94c
short-id: e9b
title: Keep a replayed note from taking a second id
priority: 5
labels:
- fix-slug-count-replay
deps:
- blocked-by:rk-number-a-note-s-footnotes-from-the-note-6e93f2c0
closed: true
---
Touches: core/0.1.0/src/state.typ, core/0.1.0/src/idea.typ, core/0.1.0/demo/rheo/content/same-title-pair.typ, core/0.1.0/demo/rheo/check.sh

A note whose id is derived from its title takes a `-2` suffix it has not
earned, because the counter that hands out those suffixes is stepped again
every time the note's body is replayed into a `#window`. One note, rendered
twice, looks like two colliding notes.

## The defect, measured

The site at `/home/lox/code/waterline` contains exactly ONE untitled dated
meeting on 4 September 2026 — `rookery/clusters/digitaltheory/pragma/meetings.typ`,
the call `#meeting(on: datetime(day: 4, month: 9, year: 2026), with: (..))`.
Verify that yourself before starting:

```
rg -n 'day: 4, month: 9, year: 2026' /home/lox/code/waterline/rookery -g '!build'
```

Its id should be `idea:meeting-with-on-4-9-26` and should stay that way. It
does not. Building that site prints a non-convergence trace for
`state("rookery-idea-scope")` whose entries across attempts include:

```
run 4: (21 vertebra entries, stable)
run 5: ... (key: "meeting-with-on-4-9-26", n: 2)
final: ... (key: "meeting-with-on-4-9-26-2", n: 0)
```

The key in that last line is the note's own id, and it gained a `-2` between
two attempts. There is no second note with that slug for it to collide with.

## Why it happens

A sibling bird recently added duplicate-id numbering: the second note deriving
a given slug becomes `<slug>-2`, the third `<slug>-3`. Anchors, one hit each:

```
rg -n '_slug-peek' /home/lox/code/_fcl/rookery/core
rg -n '_slug-record' /home/lox/code/_fcl/rookery/core
```

They print the definitions in `core/0.1.0/src/state.typ` and the call sites in
`core/0.1.0/src/idea.typ`, inside `#idea`'s main mint block.

That mint block is not executed once per note. `@rookery/core`'s own
transclusion re-renders a note's body wherever a `#window` places it, so the
block runs again, `_slug-record` fires again for the SAME note, and the
counter now believes that slug has two occupants. On a later attempt
`_slug-peek` therefore answers 2 and the note mints `<slug>-2`.

This is the same replay defect three earlier birds fixed elsewhere in this
package — a value derived from WHERE something is rendered rather than from
WHAT it is. The numbering itself is wanted and stays; what must change is that
recording an occurrence is not idempotent per note.

## The direction

Make recording idempotent: a note that has already taken a number under a slug
must get the SAME number back, not a new one, however many times its body is
rendered.

The shape to aim for: `_slug-count` stops being a slug-to-integer dict and
becomes a slug-to-list-of-occupants dict, where an occupant is something
stable about the note itself. `_slug-peek` returns the index of THIS note's
occupant if it is already listed, and the next free index otherwise;
`_slug-record` appends only when the occupant is absent. Keep the updater a
pure function of its own argument — the same discipline the rest of this file
follows, and the reason it converges.

**Choosing the occupant identity is the hard part and is NOT settled here.**
It must be stable across replays of one note and different between two genuinely
distinct notes that share a title. Candidates, none of them obviously right:
the note's resolved record as already built in `idea.typ` (the `rec` passed to
`_registry.update`), its body content, or its authoring position. Two notes
that are identical in every respect may be indistinguishable — decide what
happens then, state your choice in your report, and make sure the choice does
not reintroduce a dependence on render position.

If you conclude no stable identity is reachable at that point in the code,
STOP and report that with your evidence rather than landing a guess. A note
whose URL depends on where it is transcluded is worse than a build that warns.

## Non-goals

- **Do not remove or revert the numbering.** That two same-titled notes get
  distinct ids rather than a panic is a deliberate project decision. This bird
  fixes how occupants are counted, not whether they are.
- **Do not reach for `state("rheo-handle")` or any rheo state** to build the
  identity. This package must keep working under a plain `typst compile` with
  no rheo, which `demo/pure/` exercises.
- **Do not touch `core/0.1.0/src/bib.typ`, `urls.typ`, `outline.typ`,
  `permalink.typ` or `.marrow.typ`.** Other birds own them; one of those
  flights may still be live when you start.
- **Do not edit anything in `/home/lox/code/waterline`.** You may READ it and
  you may BUILD it as a diagnostic (see VERIFY 4), nothing else.

## VERIFY

1. From `core/0.1.0/`, `just test` passes.
2. Extend `core/0.1.0/demo/rheo/content/same-title-pair.typ` — which today has
   two same-titled notes on one vertebra — so that one of them is ALSO
   transcluded into a `#window` on another vertebra. Assert in
   `core/0.1.0/demo/rheo/check.sh` that the transcluded note's id is unchanged
   by being transcluded: the same two pages exist as before (`same-title` and
   `same-title-2`), and no third page named `same-title-3` is minted. That
   third page is the exact bug; its absence is the regression test.
3. From `core/0.1.0/demo/rheo/`, `just check` passes and prints `demo/rheo OK`.
4. Build the site as a diagnostic: copy `/home/lox/code/waterline/rookery/rheo.toml`
   to a scratch config INSIDE that repository (e.g. `rookery/.checkslug.toml`),
   replace the `repo =`/`branch =` pair in `[packages.rookery]` with
   `path = "<your flight path>"`, build with
   `rheo compile rookery --config rookery/.checkslug.toml --html --build-dir <a scratchpad dir> --input today=2026-09-20`,
   and DELETE the scratch file afterwards. In that build's
   `state("rookery-idea-scope")` trace, no key ending in `-2` may appear for
   `meeting-with-on-4-9-26`. Report the trace either way — the document may
   still fail to converge for other reasons, which is acceptable.
5. From `core/0.1.0/demo/pure/`, `just build` prints `demo/pure OK`.
6. From the repository root, `just check-versions` still prints its OK line.