---
id: rk-scaffold-rookery-cfps-package-260c3227
short-id: '26'
title: Scaffold @rookery/cfps package
priority: 2
labels:
- feat-cfps-package
deps: []
closed: false
---
## What this is

`/home/lox/code/waterline/rookery` (a separate content project, NOT this repo)
has a site-specific `#cfp`/`#venue` pair of note constructors, hand-written in
its own `_lib/template.typ`. This bird extracts them into a real, versioned
rookery package — `cfps/0.1.0/` in THIS repo, `/home/lox/code/_fcl/rookery` —
following the exact layout every other package here already uses. It does
NOT touch `/home/lox/code/waterline/rookery` at all — that site keeps its own
copy for now; a later, separate piece of work (outside this repo's birds,
tracked in that project's own issue tracker) will point it at the new
package instead.

## Reference implementation to port (read, do not edit, this file)

`/home/lox/code/waterline/rookery/_lib/template.typ`:

- Lines 115–149: the tag-key constants — `VENUE-KEY = "venue"`,
  `VENUE-CALL-KEY = "venue-call"`, `SCHOOL-KEY = "venue-school"`,
  `CFP-KEY = "cfp"`, `CFP-VENUE-KEY = "cfp-venue"`, `CFP-ID-KEY = "cfp-id"`,
  `APPLY-KEY = "submission-apply"`, `WORK-KEY = "submission-work"`,
  `ESTIMATED-KEY = "submission-estimated"`. Port every one of these EXCEPT
  `CITATION-KEY` (line 149, unrelated — belongs to that site's bibliography,
  not to cfps).
- Lines 153–199: `KINDS` (kind name → sort name) and `LADDERS` (sort name →
  `(transit: (..), terminal: (..))`) — this is the ONE thing you must NOT
  port verbatim. See "The design change" below.
- Lines 200–221: `STAGES` and `SETTLED-STAGES`, both derived from `LADDERS`
  by folding over its pairs. Port the SHAPE of these two derivations (a
  function that computes them FROM a `kinds:`/ladder config the caller
  supplies), not the literal dicts.
- Lines 222: `HIDDEN-STAGES = ("rejected", "desk-rejected", "withdrawn",
  "dropped", "missed")` — this is also SITE VOCABULARY (waterline's own
  choice of which of ITS stage names count as "came to nothing"). Do not
  port this constant. Bird `cfps-panel-css` (which depends on this one) will
  need an equivalent, but as a caller-supplied argument, not a hardcoded
  list — note this in your handoff but do not implement it here.
- Lines 224–231: `SORT-LABELS`, `SORT-DIRS` — do NOT port. These are
  waterline's own choice to group many kinds into three site sections
  (jobs/conferences/journals). The package models `kind` and its `ladder`
  only; grouping kinds into a bigger unit is the consuming site's job, done
  with an ordinary tag filter, same as any other rookery query.
- Lines 252–259: `kind-of(tags)` and `sort-of(tags)` — port `kind-of`'s
  SHAPE (a tag dictionary → which configured kind's `venue-<kind>` key is
  present). Drop `sort-of` entirely (it exists only to serve `SORT-*`, which
  you are not porting).
- Line 482–~532 (`#let venue(name, title: auto, call: none, school: none,
  tags: none, show-tags: true, ..args) = { .. }`, the whole function): port
  verbatim except the one line `(tagged-idea(VENUE-KEY))(..)` at its tail —
  see "The design change".
- Line 540–~726 (`#let cfp(name, venue: none, cycle: none, title: auto,
  kind: none, deadline: none, scheduled: none, apply: none, priority: none,
  timeline: none, work: none, estimated: false, tags: none, show-tags:
  true, ..args) = { .. }`, the whole function): port the body's LOGIC
  faithfully — the two `assert`s on `kind`, the `timeline:` stage-name
  validation loop, the `own` tag dictionary it builds, the composed
  `title:` (venue id + cycle), the `lapsed`/`answered` derivation feeding
  `todo-tags(closed: lapsed or answered)`, the in-body `rail` (a `context`
  block calling `entries(timeline: timeline)` then `timeline-view((:), t,
  today: TODAY, ladder: ladder)`, gated so the "Timeline" head only prints
  when `target() == "html" and timeline-of(t).len() > 0`), and the venue
  backlink (`ref(label("idea:" + venue))`) appended after the body and
  rail. Change how `kind`/`ladder` are resolved — see below — and change
  `TODAY` to a `today:` parameter, since this package has no site-level
  `TODAY` constant to reach for (see "today: is always explicit" below).
- `waterline/rookery/_lib/lib.typ` lines 100–116 (`submission-state`) and
  129–150 (`cfp-state`, which strips the two reserved stage names
  `"deadline"`/`"scheduled"` — `@rookery/timeline`'s `DEADLINE-STAGE`/
  `SCHEDULED-STAGE` — before asking what has actually happened, so an
  overdue-but-unanswered call reads as `"open"` rather than falsely
  `"in-flight"`): port `cfp-state` verbatim in logic (it already takes
  `ladder:`/`today:` as parameters, so no design change needed here), and
  drop `submission-state` — `cfp-state` supersedes it, there is no separate
  "submission" note any more.

## The design change: `kind`/`ladder` become caller configuration

Waterline's `KINDS`/`LADDERS` hardcode ITS OWN domain — postdoc, tenure-track,
conference, journal, etc. A real package cannot own that vocabulary, for
exactly the reason `@rookery/timeline`'s own `ladder.typ` gives for why
`is-settled`/`rung`/`next-stage` all take `ladder:` as a parameter rather than
a constant — read `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/ladder.typ`
lines 1–21 (the file's own header comment, "WHY A PARAMETER") before writing
a line of this bird's code. `accepted` ends a conference submission and is
the middle of a journal's; a package cannot know that, so it must not guess
it.

So: export a **factory**, not a bare top-level `#cfp`/`#venue` pair — the
same shape `@rookery/meetings`' `meetings(..)` (see
`/home/lox/code/_fcl/rookery/meetings/0.1.0/src/lib.typ` line 119) and
`@rookery/bibtex`'s `bibtex(..)` (see
`/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ` line 66) already use
for a package that must be bound to caller-supplied configuration before it
is usable:

```typc
#let cfps(kinds: (:)) = {
  // `kinds` is a dictionary: kind name -> (sort: <string>, ladder: (transit: (..), terminal: (..))).
  // Example a caller would write:
  //   #let (venue, cfp) = cfps(kinds: (
  //     postdoc: (sort: "job", ladder: (transit: ("submitted", ..), terminal: ("offered", "rejected", ..))),
  //     conference: (sort: "conference", ladder: (transit: (..), terminal: (..))),
  //   ))
  // Validate eagerly: every kind's `ladder` must be a dictionary with `transit:`/`terminal:` arrays of
  // strings (mirror the shape @rookery/timeline's own `_assert-ladder` in ladder.typ:64 checks, so a
  // caller gets the same class of error message this package's underlying calls would raise anyway —
  // but assert it HERE too, eagerly at factory-construction time, not lazily inside the first #cfp call,
  // since a bad `kinds:` should fail as soon as it is given rather than on whichever call happens to hit it).
  // Derive STAGES/SETTLED-STAGES here, once, the same fold waterline's template.typ:202-221 does but over
  // `kinds.values()` instead of a hardcoded LADDERS.
  // Return (venue: .., cfp: .., cfp-state: ..) — the venue/cfp constructors below, and a `cfp-state`
  // pass-through bound to nothing (it already takes `ladder:` per-call, so it can be exported bare,
  // same function every time — no closure needed over `kinds`).
  ..
}
```

`kind-of(tags)` (template.typ:252) becomes a closure over `kinds.keys()`
inside this factory, the same way `KINDS.keys()` is closed over today — the
logic does not change, only where the vocabulary comes from.

## `today:` is always explicit, never a package-level constant

Waterline's `#cfp` reaches for a module-level `TODAY` (its own build-time
constant). This package has no such thing and must not invent one —
`@rookery/timeline` itself never calls `datetime.today()` (see
`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ` lines 27–46 for
why) and always takes `today:` as an explicit argument, falling back to
`document.date` inside a `context`. Give the returned `cfp` constructor a
`today: none` parameter with that exact fallback, resolved via
`@rookery/timeline`'s own `_today`-shaped pattern: read `document.date`
inside `context` if `today:` is not given, and panic with a clear message if
neither is set (do not silently default to any date). The `rail`'s `context`
block already needs `context` for `target()`; resolve `today:` inside that
same block rather than adding a second one.

## Steps

1. Create the package directory `/home/lox/code/_fcl/rookery/cfps/0.1.0/`
   with `typst.toml`, `Justfile`, `.gitignore`, `src/lib.typ`,
   `src/cfp.typ`, mirroring `meetings/0.1.0`'s layout exactly (verbatim
   files below). This is a PURE Typst package (no `package.json`, no vite
   build) — same category as `core`, `timeline`, `meetings`, `bibtex`; see
   `/home/lox/code/_fcl/rookery/CLAUDE.md` lines 227–260 for that
   classification and why it matters (the `entrypoint`/`css_stylesheet`
   fields point straight at `src/`, with no `dist/` step).

2. `typst.toml` (copy `meetings/0.1.0/typst.toml`'s shape exactly, changing
   only the fields below):
   ```toml
   [package]
   name = "cfps"
   version = "0.1.0"
   compiler = "0.15.0"
   entrypoint = "src/lib.typ"
   authors = ["The Free Computing Lab <https://freecomputinglab.ohrg.org>"]
   license = "MIT"
   description = "A venue and its calls for @rookery/core — deadline, portal, and what happened when one was answered"
   repository = "https://github.com/freecomputinglab/rookery"

   [tool.rheo]
   min_version = "0.6.2"
   ```
   No `[tool.rheo.html]`/`css_stylesheet` entry yet — the CSS is a separate,
   dependent bird (`cfps-panel-css`, blocked on this one) that will add that
   section along with `src/cfps.css`. Do not add a `css_stylesheet` line
   pointing at a file that does not exist yet.

3. `Justfile` (copy `meetings/0.1.0/Justfile`'s `default:` recipe verbatim,
   changing only the package name in its echoed string; write a minimal
   `test:` recipe that just compiles a one-file smoke fixture — see step 5 —
   since there is no full test suite yet; a later bird adds the real one):
   ```
   default:
       @echo "@rookery/cfps: pure Typst package, entrypoint is src/lib.typ directly — nothing to build"

   test:
       mkdir -p test/build
       typst compile --features html --root . --format html test/smoke.typ test/build/smoke.html
       @echo "smoke OK"
   ```

4. `.gitignore`:
   ```
   dist/
   test/build/
   ```

5. `src/cfp.typ` — the real content. Structure:
   - `#import "@rookery/core:0.1.0": tagged-idea` (only `tagged-idea` is
     needed directly; `venue`/`cfp` build on it the same way
     `waterline/rookery/_lib/template.typ`'s own do today).
   - `#import "@rookery/timeline:0.1.0": DEADLINE-STAGE, SCHEDULED-STAGE, entries, is-settled, stage-of, timeline-of, timeline-view, todo-tags` —
     check this exact list against
     `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/lib.typ`'s own exports
     (it star-imports `@rookery/core` too and re-exports `fragment.typ`,
     `read.typ`, `when.typ`, `ladder.typ`, `index.typ`, `view.typ`,
     `upcoming.typ` — every name above is exported from one of those) —
     add any this list is missing rather than reaching into a private
     `_`-prefixed name.
   - Port the tag-key constants (step-list item under "Reference
     implementation" above).
   - Write `_assert-ladder`-style validation for `kinds:` (see "The design
     change").
   - Write `venue(name, title: auto, call: none, school: none, tags: none,
     show-tags: true, ..args)`, ported from template.typ:482, changing only
     the tail: it currently calls `(tagged-idea(VENUE-KEY))(..)` — that stays
     exactly as it is, `tagged-idea` imported directly from
     `@rookery/core`, no `dated()` wrapper needed (a venue carries no dates
     of its own in the reference implementation either).
   - Write `cfp(name, venue: none, title: auto, kind: none, deadline: none,
     scheduled: none, apply: none, timeline: none, work: none, estimated:
     false, today: none, tags: none, show-tags: true, ..args)`, ported from
     template.typ:540, with these changes from the reference:
     - Drop `cycle:`/`priority:` entirely — both are waterline's own
       worklist concerns (a "todo" system this package does not have an
       opinion on: no `priority:` parameter exists here, and `own +=
       todo-tags(..)`'s `priority:` argument becomes `priority: none`
       always, dropping the `own.insert(CFP-ID-KEY, name)` line's `cycle`
       half of the composed title along with it — the composed `title:` in
       the reference (template.typ ~594–610) becomes just the venue id, with
       no cycle half; a caller wanting a cycle in the title passes an
       explicit `title:`). Do NOT invent a `cycle:` parameter — that is a
       call site's own tagging convention, not this package's business (see
       `#let filed-under`/`#let calls-for` in the reference, which you are
       NOT porting — a caller builds its own such wrapper on top of the
       plain `cfp` this bird exports).
     - `kind`/`ladder` resolve against the factory's closed-over `kinds:`
       dictionary rather than the module-level `KINDS`/`LADDERS`.
     - `today:` resolves as described above rather than reaching for a
       module constant.
     - Keep `todo-tags(closed: lapsed or answered, ..)` — `@rookery/todos`
       is a real dependency here (add it to `typst.toml`... actually check:
       does `todo-tags` live in `@rookery/todos` or `@rookery/timeline`? The
       reference imports it in the big block at template.typ:14-17 from
       `"rookery.typ"`, which re-exports both timeline AND todos — CONFIRM
       which package actually defines `todo-tags` by grepping
       `/home/lox/code/_fcl/rookery/todos/0.1.0/src/*.typ` and
       `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/*.typ` for `#let
       todo-tags` before importing, and add that package as a real
       `[dependencies]`... Typst packages declare dependencies by import
       path only, there is no manifest dependency list to edit — just get
       the import path right.
   - Export `venue`, `cfp`, and a plain re-export of `cfp-state` (from the
     dependent bird's module — for THIS bird, stub `cfp-state` in
     `src/cfp.typ` too, ported from `waterline/rookery/_lib/lib.typ`
     lines 129–150, since the panel bird depends on this one and needs it
     already present) from a factory function — name it `cfps(kinds:)` — that
     returns `(venue: venue, cfp: cfp, cfp-state: cfp-state)` as a
     dictionary, exactly the shape `meetings(..)` returns from
     `meetings/0.1.0/src/lib.typ` (check that file's own return shape at the
     tail of its `meetings(..)` definition for the precedent).

6. `src/lib.typ`:
   ```typc
   #import "cfp.typ": *
   ```
   (Mirrors every other package's `lib.typ` being a thin star-import of its
   real source files — see the file lists already gathered for `todos`,
   `search`, `bibtex`.)

7. `test/smoke.typ` — a minimal fixture proving the factory and both
   constructors parse and run:
   ```typc
   #import "/src/lib.typ": cfps
   #let (venue, cfp) = cfps(kinds: (
     postdoc: (sort: "job", ladder: (transit: ("submitted",), terminal: ("offered", "rejected"))),
   ))
   #venue("acme", title: [Acme University])[A test venue.]
   #cfp(
     "acme-postdoc-26",
     venue: <acme>,
     kind: "postdoc",
     deadline: datetime(year: 2026, month: 1, day: 1),
     today: datetime(year: 2025, month: 12, day: 1),
   )[A test call.]
   ```
   Adjust argument names/shapes if your actual implementation's signature
   ended up different from this sketch — the point of this fixture is that
   it compiles, not that it matches this exact snippet byte for byte.

## Non-goals

- Do NOT write the `#cfps(..)` rounds-table panel view, or any CSS — those
  are `cfps-panel-css`, a separate bird blocked on this one.
- Do NOT write `readme.md` — a separate bird, `cfps-tests-readme`, blocked on
  both this one and `cfps-panel-css`, owns the readme so two concurrent
  birds never edit the same file.
- Do NOT touch anything under `/home/lox/code/waterline/rookery` — that
  site's own migration onto this new package is separate work, tracked
  elsewhere, not part of this bird.
- Do NOT port `SORT-LABELS`/`SORT-DIRS`/`sort-of`/`HIDDEN-STAGES` — see
  "Reference implementation" above for why each is waterline's own
  vocabulary rather than the package's.
- Do NOT add a `cycle:` or `priority:` parameter to `cfp(..)` — see step 5.

Touches: cfps/0.1.0/typst.toml, cfps/0.1.0/Justfile, cfps/0.1.0/.gitignore, cfps/0.1.0/src/lib.typ, cfps/0.1.0/src/cfp.typ, cfps/0.1.0/test/smoke.typ

## VERIFY

```
cd /home/lox/code/_fcl/rookery/cfps/0.1.0
just test
```
must print `smoke OK` with no Typst error. Then, from the repo root:
```
cd /home/lox/code/_fcl/rookery
just build
```
must still succeed (confirms the new package did not break anything the
root Justfile walks).