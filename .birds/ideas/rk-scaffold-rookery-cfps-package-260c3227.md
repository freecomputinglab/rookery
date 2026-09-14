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
NOT touch `/home/lox/code/waterline/rookery` at all — that site has its own
bird, `wl-close-cfp-through-rookery-todos-not-a-71011bf4`, filed in its own
tracker, to fix the same design problem in its current hand-written copy; a
further, later piece of work (not this one) would point that site at this
package instead of its own copy.

## The two things a real package has to fix that the reference gets wrong

The reference implementation (`waterline/rookery/_lib/template.typ`) has two
design mistakes this bird must NOT reproduce. Both were found the hard way,
migrating the reference site onto this exact logic — read both before
writing a line of code.

**1. `kind`/`ladder` cannot be a package-owned constant.** Waterline
hardcodes its own domain (postdoc, tenure-track, conference, journal) in a
`KINDS`/`LADDERS` pair. A package cannot own that vocabulary, for the same
reason `@rookery/timeline`'s own `ladder.typ` gives for why `is-settled`/
`rung`/`next-stage` all take `ladder:` as a parameter rather than a constant
— read `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/ladder.typ` lines
1–21 ("WHY A PARAMETER") before writing anything. `accepted` ends a
conference submission and is the middle of a journal's; a package cannot
know that, so it must not guess it. See "Design change 1" below.

**2. A cfp must close through `@rookery/todos`' real mechanism, not a flat
flag.** The reference's `#cfp` marks itself closed with
`todo-tags(closed: <bool>)` (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ:148`),
which writes ONLY a flat marker tag. `@rookery/todos`' own `is-closed`
(`todos/0.1.0/src/tags.typ:255`, `has-stage(tags, CLOSED-STAGE)`) — the field
`today-panel`/`todo-table` actually filter on — reads a DATED entry in the
shared `@rookery/timeline` log instead, and a bare boolean never writes one.
The operator's own words: "`#cfp` should be a sort of enhanced `#todo`" and
"`@rookery/cfps` should be a 'skin' on `@rookery/todos`". See "Design change
2" below — this is the harder, more important half of this bird, and it did
not exist in this bird's first draft; if you are looking at an older copy of
this description, this section is why it changed.

## Reference implementation to port (read, do not edit, this file)

`/home/lox/code/waterline/rookery/_lib/template.typ`, current line numbers as
of this bird's filing (re-check with `grep -n` before trusting a number —
this file has been edited several times this session and may have moved
again):

- Lines 115–149: the tag-key constants — `VENUE-KEY = "venue"`,
  `VENUE-CALL-KEY = "venue-call"`, `SCHOOL-KEY = "venue-school"`,
  `CFP-KEY = "cfp"`, `CFP-VENUE-KEY = "cfp-venue"`, `CFP-ID-KEY = "cfp-id"`,
  `APPLY-KEY = "submission-apply"`, `WORK-KEY = "submission-work"`,
  `ESTIMATED-KEY = "submission-estimated"`. Port every one of these EXCEPT
  `CITATION-KEY` (unrelated — belongs to that site's bibliography).
- Lines 153–199: `KINDS` (kind name → sort name) and `LADDERS` (sort name →
  `(transit: (..), terminal: (..))`) — do NOT port verbatim. See "Design
  change 1".
- Lines 200–221: `STAGES` and `SETTLED-STAGES`, both derived from `LADDERS`
  by folding over its pairs. Port the SHAPE of these two derivations (a fold
  over a caller-supplied `kinds:` config), not the literal dicts.
- `HIDDEN-STAGES = ("rejected", "desk-rejected", "withdrawn", "dropped",
  "missed")` (near line 222) — SITE VOCABULARY (waterline's own choice of
  which stage names count as "came to nothing"). Do not port this constant;
  `cfps-panel-css` needs an equivalent, but as a caller-supplied argument.
- `SORT-LABELS`, `SORT-DIRS` (near lines 224–231) — do NOT port. Waterline's
  own choice to group many kinds into three site sections. The package
  models `kind` and its `ladder` only; grouping kinds into a bigger unit is
  the consuming site's job, done with an ordinary tag filter.
- `kind-of(tags)`/`sort-of(tags)` (near lines 252–259) — port `kind-of`'s
  SHAPE (tags → which configured kind's `venue-<kind>` key is present). Drop
  `sort-of` (exists only to serve `SORT-*`).
- `_opportunity-table(pairs)` (a private helper, added this session, near
  line 498) — port VERBATIM. It is the two-column metadata table both
  `venue`/`cfp` open their body with (a venue's `call:`, a cfp's `work:`),
  styled the same as `@rookery/meetings`' own `.meeting-fields` — see
  `cfps-panel-css` for the CSS half. `none`-valued rows drop out; an empty
  table draws nothing.
- `venue(name, title: auto, call: none, school: none, tags: none, show-tags:
  true, ..args)` (near line 517): port verbatim, including its `full`
  (`_opportunity-table((("Call", call, "url"),)); body`) and its tail —
  `(tagged-idea(VENUE-KEY))(name, title:, tags:, show-tags:, ..args.named(),
  full)`. A venue carries no dates and is not a todo, so it is the ONE
  constructor in this file that is NOT affected by Design change 2.
- `cfp(name, venue: none, cycle: none, title: auto, kind: none, deadline:
  none, scheduled: none, apply: none, priority: none, timeline: none, work:
  none, estimated: false, tags: none, show-tags: true, ..args)` (near line
  582): port the LOGIC — the two `assert`s on `kind`, the `timeline:`
  stage-name validation loop, the `own` tag dictionary, the composed
  `title:` (venue id + cycle) — but its CLOSING mechanism and its tail call
  are exactly what Design change 2 replaces; do not port those two pieces
  verbatim. The `rail` (near line 727) — a `context` block calling
  `entries(deadline: deadline, scheduled: scheduled, timeline: timeline)`,
  then `timeline-view((:), t, today:, ladder:)`, with the "Timeline" head
  gated on `target() == "html" and timeline-of(t).len() > 0` — DOES port
  verbatim: as of this session, the rail shows the WHOLE combined log —
  `submitted`, `deadline`, `rejected`, in the order they actually happened —
  rather than treating the wire as a fact stated elsewhere. The `full`'s
  order also ports verbatim: `_opportunity-table((("Work", work, "path"),))`,
  then `rail`, then a `parbreak()`, then `body`, then (if `venue != none`) a
  `parbreak()` and `ref(label("idea:" + venue))`.
- `/home/lox/code/waterline/rookery/_lib/lib.typ` — `_real-tags(tags)`
  (private, ~line 131), `real-stage-of(tags, today:)` (~line 143), and
  `cfp-state(tags, ladder:, today:)` (~line 146): port all three verbatim IN
  LOGIC. `_real-tags` strips reserved stage names — currently
  `DEADLINE-STAGE`/`SCHEDULED-STAGE` — before asking what has actually
  happened, so an overdue-but-unanswered call reads `"open"` rather than
  falsely `"in-flight"`, and a real answer dated BEFORE its own deadline
  (`cornell-humanities-26-27`, dropped 29 August against a 1 September wire)
  is not masked by the chronologically-later `deadline` entry. **Add
  `CLOSED-STAGE` to that exclusion tuple in THIS package's copy from the
  start** — `waterline`'s own bird
  (`wl-close-cfp-through-rookery-todos-not-a-71011bf4`) has to retrofit this
  because its `#cfp` did not close through the log before; this package's
  `#cfp` closes through the log from its very first version (Design change
  2), so its `cfp-state`/`real-stage-of` need the third exclusion from day
  one or every settled cfp will read its OWN `"closed"` entry back as its
  current stage. Drop `submission-state` (superseded by `cfp-state`, no
  separate "submission" note in this design at all).

## Design change 1: `kind`/`ladder` become caller configuration

Export a **factory**, not a bare top-level `#cfp`/`#venue` pair — the same
shape `@rookery/meetings`' `meetings(..)` (see
`/home/lox/code/_fcl/rookery/meetings/0.1.0/src/lib.typ` line 119) and
`@rookery/bibtex`'s `bibtex(..)` (line 66) already use for a package that
must be bound to caller-supplied configuration before it is usable:

```typc
#let cfps(kinds: (:)) = {
  // `kinds`: kind name -> (sort: <string>, ladder: (transit: (..), terminal: (..))).
  // Example a caller would write:
  //   #let (venue, cfp, cfp-state) = cfps(kinds: (
  //     postdoc: (sort: "job", ladder: (transit: ("submitted", ..), terminal: ("offered", "rejected", ..))),
  //     conference: (sort: "conference", ladder: (transit: (..), terminal: (..))),
  //   ))
  // Validate EAGERLY, at factory-construction time, mirroring the shape @rookery/timeline's own
  // `_assert-ladder` (ladder.typ:64) checks — a bad `kinds:` should fail as soon as it is given,
  // not on whichever #cfp call happens to hit the bad kind first.
  // Derive STAGES/SETTLED-STAGES here, once, the same fold waterline's template.typ:202-221 does
  // but over `kinds.values()` instead of a hardcoded LADDERS.
  // Return (venue: .., cfp: .., cfp-state: ..).
  ..
}
```

`kind-of(tags)` becomes a closure over `kinds.keys()` inside this factory,
the same way `KINDS.keys()` is closed over today — the logic does not
change, only where the vocabulary comes from.

## Design change 2: `cfp` is built on `@rookery/todos`' `todo(..)`, not bare `tagged-idea`

Read `/home/lox/code/_fcl/rookery/todos/0.1.0/src/todo.typ` lines 1–202 in
full before writing this constructor — the comments there (`_closing`,
`done:`, why a close is a date and not a bool) are the spec for this change,
not background reading.

`todo(..)` is itself `(dated(tagged-idea(TODO-KEY)))(..)` — it already
forwards `deadline:`/`scheduled:`/`timeline:` to the shared log exactly as
this package's `cfp` needs, and it ADDS `done:` (a real closing date,
folded into the log as a `CLOSED-STAGE` entry) and a `priority:` parameter
this bird's `cfp` should expose directly rather than banning:

```typc
#import "@rookery/todos:0.1.0": todo

#let cfp(
  name,
  venue: none,
  title: auto,
  kind: none,
  deadline: none,
  scheduled: none,
  apply: none,
  priority: none,
  timeline: none,
  work: none,
  estimated: false,
  today: none,
  tags: none,
  show-tags: true,
  ..args,
) = {
  // .. the two asserts on `kind`, the `timeline:` stage validation loop,
  // the `own` tag dictionary, the composed `title:` — all ported as-is ..

  // THE CLOSE DATE, not a bool. The earliest REAL (non-reserved) answer if
  // one exists — the day applying stopped being outstanding work — else the
  // deadline itself if that has passed with nothing sent, else `none` (still
  // open work). `log-stages` already exists from the validation loop above.
  let lapsed = deadline != none and resolved-today > deadline
  let real-dates = log-stages.pairs().map(p => {
    let v = p.at(1)
    if type(v) == datetime { v } else { v.at("timestamp", default: none) }
  }).filter(d => d != none)
  let close-on = if real-dates.len() > 0 {
    real-dates.sorted().first()
  } else if lapsed {
    deadline
  } else { none }

  // .. the rail and `_opportunity-table`/`full` construction, ported as-is ..

  todo(
    name,
    title: title,
    deadline: deadline,
    scheduled: scheduled,
    timeline: timeline,
    done: close-on,
    priority: priority,
    tags: own + norm-tags(tags),
    show-tags: show-tags,
    ..args.named(),
    full,
  )
}
```

(`resolved-today` is whatever this bird's `today:` resolution produces — see
"today: is always explicit" below; it is not a real identifier to import.)

This is a STRICTLY BETTER fix than a hand-rolled `todo-tags(closed: bool)`
fold: `is-closed`/the flat marker/`priority`'s own worklist behavior all come
free and correct, because `todo(..)` derives its flat marker FROM the same
log entry `done:` writes (`todo.typ:161`), so the two can never disagree —
exactly the guarantee that bare `todo-tags(closed: bool)` cannot give, since
it writes the marker with no log entry behind it at all.

Do NOT add `deps:`/`metadata:`/`active:`/`status:`/`type:` parameters to
`cfp(..)` — `todo(..)` accepts all of them, but nothing here asks a cfp to
use `@rookery/todos`' dependency graph or its own todo-kind vocabulary.
Leave them at `todo(..)`'s own defaults. The point, per the operator, is
that a cfp shows up reasonably in a consumer's `today-panel`/`todo-table`
"without any additional embellishments" — this composition is what gets
that for free; it is not an invitation to wire up more of `@rookery/todos`'
surface than a cfp needs.

`cycle:` is NOT ported — that is waterline's own tagging convention (see
`#let filed-under`/`#let calls-for` in the reference, NOT ported either — a
caller builds its own such wrapper on top of the plain `cfp` this bird
exports), not this package's business.

## `today:` is always explicit, never a package-level constant

Waterline's `#cfp` reaches for a module-level `TODAY` (its own build-time
constant). This package has no such thing and must not invent one —
`@rookery/timeline` itself never calls `datetime.today()` (see
`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ` lines 27–46) and
always takes `today:` as an explicit argument, falling back to
`document.date` inside a `context`. Give `cfp` a `today: none` parameter
with that exact fallback pattern. The `rail`'s `context` block already needs
`context` for `target()`; resolve `today:` inside that same block rather
than adding a second one, and thread the resolved value into the `close-on`
computation above too (which also needs a "now" to test `lapsed` against) —
both live inside the one `context`, so compute `close-on` there rather than
outside it.

## Steps

1. Create `/home/lox/code/_fcl/rookery/cfps/0.1.0/` with `typst.toml`,
   `Justfile`, `.gitignore`, `src/lib.typ`, `src/cfp.typ`, mirroring
   `meetings/0.1.0`'s layout. Pure Typst package (no `package.json`, no vite
   build) — same category as `core`/`timeline`/`meetings`/`bibtex`; see
   `/home/lox/code/_fcl/rookery/CLAUDE.md` lines 227–260.

2. `typst.toml` (copy `meetings/0.1.0/typst.toml`'s shape, changing only):
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
   No `[tool.rheo.html]`/`css_stylesheet` yet — `cfps-panel-css` adds that.

3. `Justfile`:
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

5. `src/cfp.typ`:
   - `#import "@rookery/core:0.1.0": tagged-idea` (for `venue` only).
   - `#import "@rookery/todos:0.1.0": todo` (for `cfp` — Design change 2).
   - `#import "@rookery/timeline:0.1.0": CLOSED-STAGE, DEADLINE-STAGE, SCHEDULED-STAGE, entries, is-settled, stage-of, timeline-of, timeline-view` —
     check this list against
     `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/lib.typ`'s exports (it
     star-imports `@rookery/core` and re-exports `fragment.typ`, `read.typ`,
     `when.typ`, `ladder.typ`, `index.typ`, `view.typ`, `upcoming.typ` — add
     any name missing from this list rather than reaching into a private
     `_`-prefixed one).
   - Port the tag-key constants and `_opportunity-table` (see "Reference
     implementation" above).
   - Write `_assert-ladder`-style eager validation for `kinds:` (Design
     change 1).
   - Write `venue(..)` verbatim (see "Reference implementation").
   - Write `cfp(..)` per "Design change 2" above, folding in the `rail`/
     `full` construction from "Reference implementation" verbatim.
   - Write `cfp-state(tags, ladder:, today:)`/`real-stage-of(tags, today:)`/
     `_real-tags(tags)` per "Reference implementation", with `CLOSED-STAGE`
     in the exclusion tuple from the start.
   - Export all of this through the `cfps(kinds:)` factory (Design change 1),
     returning `(venue: venue, cfp: cfp, cfp-state: cfp-state)` — the same
     dictionary-return shape `meetings(..)` uses.

6. `src/lib.typ`:
   ```typc
   #import "cfp.typ": *
   ```

7. `test/smoke.typ` — a minimal fixture proving the factory and both
   constructors parse and run, AND that closing actually happens:
   ```typc
   #import "/src/lib.typ": cfps
   #let (venue, cfp, cfp-state) = cfps(kinds: (
     postdoc: (sort: "job", ladder: (transit: ("submitted",), terminal: ("offered", "rejected"))),
   ))
   #venue("acme", title: [Acme University])[A test venue.]
   #cfp(
     "acme-postdoc-26",
     venue: <acme>,
     kind: "postdoc",
     deadline: datetime(year: 2026, month: 1, day: 1),
     timeline: (submitted: datetime(year: 2025, month: 12, day: 20), offered: datetime(year: 2026, month: 2, day: 1)),
     today: datetime(year: 2026, month: 2, day: 15),
   )[A test call, answered and settled.]
   ```
   Adjust argument names/shapes if your implementation's signature ended up
   different — the point is that it compiles AND that the minted note's own
   tags show it closed (spot-check with a `#context` block asserting
   `is-closed` — imported from `@rookery/todos` — on the note's registered
   tags, if that is reachable from a fixture at this stage; if not, leave the
   assertion for `cfps-tests-readme`'s real test suite and just confirm this
   fixture compiles).

## Non-goals

- Do NOT write the `#cfps(..)` rounds-table panel view, or any CSS —
  `cfps-panel-css`, blocked on this bird.
- Do NOT write `readme.md` — `cfps-tests-readme`, blocked on this bird and on
  `cfps-panel-css`.
- Do NOT touch `/home/lox/code/waterline/rookery`.
- Do NOT port `SORT-LABELS`/`SORT-DIRS`/`sort-of`/`HIDDEN-STAGES`/
  `submission-state` — see "Reference implementation" for why each does not
  belong in the package.
- Do NOT add a `cycle:` parameter, or `deps:`/`metadata:`/`active:`/
  `status:`/`type:` parameters — see "Design change 2".

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
must still succeed.