---
id: rk-moves-timeline-off-tagged-idea-0bec4286
short-id: 0b
title: Moves timeline off tagged-idea
priority: 3
labels:
- migrate-tagged-idea
deps:
- blocked-by:rk-adds-tag-and-base-tags-to-idea-9960f68e
closed: true
---
Touches: timeline/0.1.0/src/lib.typ, timeline/0.1.0/src/fragment.typ, timeline/0.1.0/test/units.typ, timeline/0.1.0/readme.md

Migrate `@rookery/timeline` off `@rookery/core`'s `tagged-idea` factory, and
drop this package's own decorated re-export of it.

## Why

`@rookery/core`'s `#idea` now takes two MERGING tag arguments — `tag:` (one tag
name, string only) and `base-tags:` (none, a string, an array of strings, or a
dictionary binding a value per tag) — which a caller's own `tags:` is merged ON
TOP OF rather than replacing. That makes `idea.with(..)` a safe way to build a
note constructor, which is the one thing `tagged-idea` existed to provide.
`tagged-idea` is deleted from core by a later bird; this bird moves timeline
off it first.

This package's re-export becomes unnecessary rather than merely renamed.
`dated(mint)` returns a closure with a `..args` sink that forwards every named
argument to `mint` untouched, so `base-tags:` rides straight through — and
`timeline`'s own `idea` is already `dated(_rk.idea)`. A consumer therefore
writes:

    #import "@rookery/timeline:0.1.0": idea
    #let submission = idea.with(base-tags: "submission")

and gets the date arguments and the tag family together, with nothing left for
a decorated factory to add.

**A note on how `@rookery/core` resolves here:** it comes from the Typst
package cache, which on this machine symlinks
`~/.cache/typst/packages/rookery/core/0.1.0` to the repository's own
`core/0.1.0`. You are therefore compiling against the core in the MAIN
checkout, not against a copy inside this flight — which is correct, and is why
this bird could not run before core's own bird landed. If `just test` fails
with `unknown named argument: base-tags`, that landing has not happened; STOP
and report it rather than working around it.

## Where

Run the anchor commands from the FLIGHT ROOT (the directory containing
`core/`, `timeline/`, `todos/` …). Each was run before filing and printed
exactly ONE hit.

**Site 1 — the decorated factory and its banner comment,** in
`timeline/0.1.0/src/lib.typ` (around line 106 as of filing). The comment block
directly above it begins "The FACTORY, decorated too".

    rg -Fn '#let tagged-idea(..family) = dated(_rk.tagged-idea(..family))' timeline/

**Site 2 — `dated`'s example comment,** in `timeline/0.1.0/src/fragment.typ`
(around line 253).

    rg -Fn '#let dated-note = dated(tagged-idea("note"))' timeline/

**Site 3 — `dated`'s type-assert message,** same file (around line 290).

    rg -Fn '`idea`, a `tagged-idea(..)` factory, or another decorated one. Got ' timeline/

**Site 4 — the export-surface assertion,** in `timeline/0.1.0/test/units.typ`
(around line 361), under the comment "The two that ARE decorated."

    rg -Fn '#assert.eq(type(tagged-idea("venue")), function)' timeline/

**Site 5 — the readme's "two names are overridden" paragraph** (around line
97).

    rg -Fn '`dated(rookery.idea)`; `tagged-idea` is the same decoration applied to the factory,' timeline/

**Site 6 — the readme's `dated(mint)` example** (around line 240).

    rg -Fn '#let submission = dated(tagged-idea("submission"))' timeline/

If an anchor does not resolve, widen the `rg` to the flight root. If it is
still gone, STOP and report the miss naming the landmark (the `#let
tagged-idea` line, the `dated` function, the readme heading) rather than
guessing or recreating text.

## Steps

1. **Site 1 — delete the `#let tagged-idea(..family) = ..` line and the whole
   comment block above it** (the block beginning "The FACTORY, decorated too"
   and ending with the "A WHOLESALE SINK" paragraph). Leave `#let idea =
   dated(_rk.idea)` and its own comment exactly as they are.

   In its place, extend the comment on `#let idea` — or add one short block —
   saying that a consumer builds a family of its own with
   `idea.with(base-tags: ..)`, since `dated`'s sink forwards core's merging tag
   arguments untouched. Follow the repository `CLAUDE.md`'s comment style:
   present tense, describe what is there, no "used to", no issue ids, no
   interior section banners.

2. **Site 2 — update `dated`'s example comment** from

       #let dated-note = dated(tagged-idea("note"))

   to

       #let dated-note = dated(idea).with(base-tags: "note")

   where `idea` is core's. Keep the line below it (`#dated-note("ship",
   deadline: d, timeline: (submitted: d2))[..]`) unchanged.

3. **Site 3 — update `dated`'s assert message** so it no longer names a factory
   that will not exist. It currently reads "`idea`, a `tagged-idea(..)`
   factory, or another decorated one. Got ". Replace the middle clause so it
   reads as rookery's `idea`, an `idea.with(..)` constructor, or another
   decorated one. Do not change the assert's CONDITION — it still checks
   `type(mint) == function`.

4. **Site 4 — update the export-surface assertion.** Replace

       #assert.eq(type(tagged-idea("venue")), function)

   with

       #assert.eq(type(idea.with(base-tags: "venue")), function)

   and fix the comment above it ("The two that ARE decorated.") to say that
   `idea` is the one decorated name. Then check the file's import list at the
   top: if `tagged-idea` is named there, remove it.

   Run `rg -Fn 'tagged-idea' timeline/0.1.0/test/units.typ` afterwards and
   expect zero hits.

5. **Site 5 — rewrite the readme's "two names are overridden" paragraph** to
   say that ONE name is overridden (`idea`, which is `dated(rookery.idea)`) and
   that a family built over this skin is `idea.with(base-tags: ..)`, which
   takes the date arguments because `dated`'s sink forwards core's tag
   arguments untouched. Keep the closing list of pass-through names (`window`,
   `ideas`, `tag-data`, `note-href`, `rookery`) as it is.

6. **Site 6 — update the readme's `dated(mint)` example.** The import line
   `#import "@rookery/core:0.1.0": idea, tagged-idea` drops `tagged-idea`, and
   the "or put your own tag family on top" example becomes:

       #let submission = dated(idea).with(base-tags: "submission")

7. **Sweep the package for any remaining mention.** Run

       rg -Fn 'tagged-idea' timeline/

   and resolve every hit — prose in `readme.md` included — so the count reaches
   ZERO. Each remaining mention is either an example to rewrite in the same
   `idea.with(base-tags: ..)` shape, or a sentence whose claim is now false and
   must state what is actually there.

## Non-goals

- **Do NOT touch any package outside `timeline/0.1.0/`.** Not `core`, not
  `todos`, not `bibtex` — they have birds of their own.
- Do not change `dated`'s behaviour, its signature, or `normalize-tags`. Only
  its example comment and its assert MESSAGE change.
- Do not add a compatibility shim, alias or deprecation stub for
  `tagged-idea`. It goes, and consumers use `idea.with(..)`.
- Do not change `timeline`'s `idea` export, the timeline-log machinery, or
  `typst.toml`.

## VERIFY

Run from `<flight>/timeline/0.1.0/`.

1. The unit fixture compiles, which is this package's whole harness:

       just test

   Expect it to end with `units OK`.

2. No mention of the removed factory survives anywhere in the package. From
   the flight root:

       rg -Fn 'tagged-idea' timeline/

   Expect ZERO hits.

3. The readme documents the replacement:

       rg -Fn 'base-tags' timeline/0.1.0/readme.md

   Expect at least two hits.