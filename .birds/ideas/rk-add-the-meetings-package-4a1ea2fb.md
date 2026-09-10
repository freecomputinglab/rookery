---
id: rk-add-the-meetings-package-4a1ea2fb
short-id: 4a
title: Add the meetings package
priority: 3
labels:
- feat-meetings-package
deps: []
closed: false
---
Create a new pure-Typst package `@rookery/meetings:0.1.0` at
`/home/lox/code/_fcl/rookery/meetings/0.1.0/`, exporting `#meeting` — a wrapper
around `@rookery/core`'s `#idea` that takes `with:` (who was in the room) and
`on:` (when the meeting happened).

**Where this surface comes from.** It already exists, hand-rolled, in a consuming
project: `/home/lox/code/waterline/rookery/_lib/template.typ` carries
`MEETING-KEY` (line 97), `MEETING-WITH-KEY` (line 114), `_meeting-with-block`
(lines 480-489) and the `meetings(..)` factory (lines 491-571). Meetings are the
third note family that project invented and the only one with no lifecycle, and
none of it is project-specific — so it moves into the family, where the readers
(`meeting-with-of`, `occurred-of`), the stylesheet and the tests can live with it.
`on:` is the one thing that is NEW: waterline's version has no date argument at
all and leans on rookery's `created:`.

You do not need to read waterline to do this bird. Every line of the package is
below, and it has been compiled and asserted already (see MEASURED).

## Decisions already made — do NOT re-derive these

1. **`on:` writes BOTH a log entry and `created:`.** It inserts an `occurred`
   entry into @rookery/timeline's log (via that package's `entries(..)` tag
   fragment) AND passes the same datetime to rookery core's `created:`. The log
   entry is what makes the date a timeline EVENT; the row field is what makes it a
   date that is free to filter and sort by — rookery keeps `created` on every
   `ideas()` row, where a tag value (the log included) costs a `tag-data()` walk to
   reach. Giving both `on:` and `created:` is an ERROR (two answers to one
   question), asserted with a message naming the fix.
2. **The record block and the rail live in the note's BODY, above the prose**, not
   in a page template. @rookery/core's transclusion renders a note's body and knows
   nothing about a consuming project's page chrome, so a rail drawn by a template
   exists on the note's own minted page and nowhere else. This is the same move
   `#submission` makes in waterline (`_lib/template.typ` lines 988-1024, "THE RAIL
   LIVES IN THE BODY so it survives transclusion").
3. **The rail is drawn with `(:)` as `#timeline-view`'s first argument**, not the
   note's own registry row. That argument is what makes @rookery/timeline prepend
   rookery's `created` to the rail — and `on:` has just set `created` to the very
   date the `occurred` entry carries, so passing a row would draw the same day
   twice.
4. **`today:` is a parameter, on the factory and on each call.** Typst has no wall
   clock, `#timeline-view` needs a reference date to tell what has happened from
   what is booked, and @rookery/timeline panics rather than guessing one (see its
   `src/when.typ` `_today`). A project stamps its build date in as an input and
   passes it once to `meetings(..)`; a per-call `today:` overrides it. A document
   with its own `#set document(date:)` needs neither.
5. **Both dependencies are imported as ALIASED MODULES** (`as core`, `as tl`),
   never star-imported. A Typst module re-exports every top-level binding it holds,
   star-imported ones included — so a star import here would make this package a
   second source of `idea`, `window` and `rookery`, and a consumer star-importing
   several rookery packages resolves those by IMPORT ORDER. An undecorated `window`
   arriving from here would silently shadow @rookery/todos' skinned one. This is
   the trap waterline's `_lib/rookery.typ` documents at its lines 26-54.
6. **`core.tagged-idea`, NOT @rookery/timeline's decorated one.** This package
   folds `scheduled:`/`deadline:`/`timeline:` into `tl.entries(..)` itself, so it
   needs no skin — and it must, because it has to hand the SAME tag dictionary to
   `#timeline-view` for the rail. Do not add `dated(..)` on top: the fragment would
   then be built twice.
7. **Its own CSS classes (`.meeting-fields-head`, `.meeting-fields`) and its own
   complete stylesheet.** The block is @rookery/bibtex's citation-fields block by
   design — one gutter, one hairline, one label size across the family — but a
   project using this package must not have to install THAT one to see a meeting's
   header, so the rules are copied and re-keyed rather than borrowed. waterline's
   current markup emits `class="citation-fields-head meeting-fields-head"`; the
   package drops the `citation-*` half.
8. **The synthesized title.** `Meeting with <refs> on <date>` where both are
   given, `Meeting with <refs>` with only `with:`, `Meeting on <date>` with only
   `on:`, and nothing at all with neither (core then falls back to the body's first
   sixty characters). An author's own `title:` always wins. The names are `ref`s,
   not text — a person's name is typed once, on their own note — and the date is
   @rookery/timeline's own `_fmt-day` short form, so the title cannot disagree with
   the rail two lines below it.

## MEASURED, on typst 0.15.1, before this bird was filed

Every claim below was checked by compiling the exact files in this bird:

- `tl._fmt-day(datetime(year: 2026, month: 9, day: 10))` is `"10.9.26"`. Underscore
  names travel through a star import, so `_fmt-day` — defined in
  @rookery/timeline's `src/read.typ` and star-imported into its `src/lib.typ` — is
  reachable as `tl._fmt-day` through an aliased module import.
- `occurred` passes @rookery/timeline's stage-name assert (it is not one of that
  package's three reserved names, `scheduled`/`deadline`/`closed`).
- the note's flattened `label` on its `ideas()` row comes out as exactly
  `"Meeting with Finale Doshi-Velez on 10.9.26"` — the ref in the title resolves
  to the target note's own title in the plain-text projection.
- the card's document order is: `.meeting-fields-head`, `.meeting-fields` `<dl>`,
  `<ol class="timeline">`, then the prose.
- a past-dated meeting's rail is exactly one
  `<li class="timeline-event timeline-past timeline-current">` carrying `10.9.26`
  and the stage `occurred`; a future-dated one draws `timeline-future`.
- `just test` (the recipe below) is green, and root `just check-versions` accepts
  the package (`meetings/0.1.0/` matches `name`/`version`, and every
  `@rookery/<pkg>:<ver>` spec it contains resolves to a directory in the repo).

## Steps

1. `mkdir -p /home/lox/code/_fcl/rookery/meetings/0.1.0/src /home/lox/code/_fcl/rookery/meetings/0.1.0/test`
2. Create each file below with EXACTLY the content given. They are verified
   sources, not sketches — do not reformat, re-comment or "improve" them.
3. `chmod +x meetings/0.1.0/test/check.sh`.
4. Run the VERIFY commands at the foot of this bird.

### `meetings/0.1.0/typst.toml`

```toml
[package]
name = "meetings"
version = "0.1.0"
compiler = "0.15.0"
entrypoint = "src/lib.typ"
authors = ["The Free Computing Lab <https://freecomputinglab.ohrg.org>"]
license = "MIT"
description = "A meeting note for @rookery/core — who was in the room, when it happened, and what was said"
repository = "https://github.com/freecomputinglab/rookery"

[tool.rheo]
min_version = "0.6.2"

[tool.rheo.html]
css_stylesheet = "src/meetings.css"
```

### `meetings/0.1.0/.gitignore`

```gitignore
/dist/
/node_modules/
build/
```

### `meetings/0.1.0/Justfile`

```makefile
default:
    @echo "@rookery/meetings: pure Typst package, entrypoint is src/lib.typ directly — nothing to build"

# Two fixtures. `test/units.typ` asserts every VALUE `#meeting` derives — the tags,
# the date, the synthesized title — and `test/view.typ` plus `test/check.sh` assert
# the MARKUP and, above all, the order of the three blocks in a meeting's card.
#
# `--root .` so a fixture's `#import "/src/lib.typ"` resolves against THIS package.
# `--features html` for parity with this repo's other Justfiles.
#
# BOTH FIXTURES COMPILE TO HTML, where timeline's units fixture compiles to a
# throwaway PDF. `#meeting`'s record block is `html.elem`, which a paged export
# drops with a warning per element — so a paged units run is a wall of warnings
# about markup this package only claims to draw on the web. The cost is that the
# paged branch of `#timeline-view` is not exercised here; it is exercised in
# @rookery/timeline's own fixture, which owns it.
#
# `mkdir` first: unlike `rheo`, `typst compile` does not create its output
# directory and fails with "No such file or directory" on a fresh checkout, since
# `test/build/` is gitignored and never committed.
test:
    mkdir -p test/build
    typst compile --features html --root . --format html test/units.typ test/build/units.html
    @echo "units OK"
    typst compile --features html --root . --format html test/view.typ test/build/view.html
    ./test/check.sh
```

### `meetings/0.1.0/src/lib.typ`

```typst
// @rookery/meetings — a meeting: who was in the room, when it happened, what was
// said.
//
// A meeting is the smallest note family in this repo and the only one with no
// lifecycle: it is over the moment it happened. What makes it worth a package is
// the two things a plain `#idea` cannot say — WHO it was with, and WHEN it took
// place — and the fact that both are askable across a whole rookery once they are
// stored rather than written into prose.
//
//   #import "@rookery/meetings:0.1.0": meeting
//   #meeting(<doshi-velez-26-9-10>, with: <doshi-velez-finale>,
//            on: datetime(year: 2026, month: 9, day: 10), today: TODAY)[..]
//
// TWO ALIASED IMPORTS, and the aliases are load-bearing rather than tidy. A Typst
// module re-exports every top-level binding it holds, star-imported ones included,
// so `#import "@rookery/core:0.1.0": *` here would make this package a second
// source of `idea`, `window` and `rookery` — and a consumer star-importing several
// rookery packages resolves those names by IMPORT ORDER, so an undecorated `window`
// arriving from here would silently shadow @rookery/todos' skinned one. Aliased,
// this module exports its own five names and nothing else.
#import "@rookery/core:0.1.0" as core
#import "@rookery/timeline:0.1.0" as tl

// The flat tag every meeting carries, so `tags:meeting` is askable corpus-wide.
#let MEETING-KEY = "meeting"

// WHO WAS IN THE ROOM, as idea NAMES — `("hagen-blix", "ed-ongweso")`. A REFERENCE
// to other ideas, which is what earns it a key of its own rather than a place in
// the flat tag list. An ARRAY, a meeting being a thing that happens between
// several.
//
// THE NAMES ARE MEANT TO BE PEOPLE and are not required to be. Nothing here
// checks: the key names the RELATION rather than a family, so whatever the target
// note turns out to be — a person, a lab, a reading group — "this meeting was with
// that" is the same fact.
//
// A TAG PER PERSON IS THE OTHER DESIGN AND IS WORSE. A tag key is interpolated
// into an `idea-tag-<key>` class, so every name that ever walked into a room would
// have to stay CSS-safe; and a person is already a note, so a tag would be a
// second, thinner copy of one. A valued key keeps the person's own page as the only
// place they are described, and `tags:meeting-with` still asks "which meetings
// record who was there".
#let MEETING-WITH-KEY = "meeting-with"

// THE STAGE `on:` WRITES into @rookery/timeline's log. Not one of that package's
// three reserved names (`scheduled`, `deadline`, `closed`) — those are plans and a
// closing, and this is the event itself.
#let OCCURRED-STAGE = "occurred"

// Readers, for a consumer building a view over meetings. Both take the tag
// DICTIONARY — `tag-data()`'s per-note value, or an `ideas(values: true)` row's
// `tags-dict` — so neither needs a registry read of its own.
#let meeting-with-of(tags) = tags.at(MEETING-WITH-KEY, default: ())
#let occurred-of(tags) = tl.stage-date(tags, OCCURRED-STAGE)

// A page tag about to be interpolated into an `idea-tag-<key>` class. Rejected
// here rather than in a stylesheet, where the only symptom is a rule that silently
// never matches.
#let _css-safe(name) = assert(
  type(name) == str and name.match(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$")) != none,
  message: "@rookery/meetings: the page tag "
    + repr(name)
    + " is not usable as a CSS class fragment. Use alphanumerics and interior hyphens only.",
)

// `with:` takes either spelling a rookery reference does — a LABEL
// (`<hagen-blix>`, the form to prefer, since it reads as the reference it is) or a
// bare string — and one name needs no array ceremony. `core._norm` flattens all of
// them, a full `idea:x` included, to the one name the tag stores.
#let _who(with) = {
  if with == none { return () }
  let given = if type(with) == array { with } else { (with,) }
  given.map(core._norm)
}

// EACH NAME AS ITS OWN `ref`, which does two things no written link can. It takes
// the RESOLVED TITLE of the note it points at (rookery's `show ref: hyperlink`
// rule), so a person's name is typed once, on their own note; and it EARNS THEM A
// BACKLINK, so their page lists every meeting they were in.
#let _refs(who) = who.map(n => ref(label("idea:" + n))).join(", ")

// THE HEADER A MEETING OPENS WITH: a labelled row, not a sentence. "With Hagen
// Blix" as a paragraph reads as the note's first thought; a labelled row reads as
// the note's record, which is what it is — and what a body full of what was
// actually said should not have to open by restating.
//
// A DIV, NOT A HEADING, for the label: it names the block under it and a meeting's
// body carries real headings, so a heading here would claim a place in the page's
// outline above them.
//
// HTML ONLY, in the sense that `html.elem` contributes nothing at all on a paged
// target — element and children alike. A meeting's prose still renders there; its
// record does not. That is the same trade every view in this family makes.
#let _fields(who) = {
  html.elem("div", attrs: (class: "meeting-fields-head"), "Meeting")
  html.elem("dl", attrs: (class: "meeting-fields"), {
    html.elem("dt", "With")
    // COMMA-JOINED, not one per line: a person's name carries no commas of its
    // own, so a row of them reads as a list without needing a column.
    html.elem("dd", _refs(who))
  })
}

// `#meetings(..)` -> a `#meeting` factory carrying a page's own tags:
//
//   #let meeting = meetings("digital-theory-lab", today: TODAY)
//   #meeting(<blix-27-8-26>, with: <hagen-blix>, on: d)[..]
//
// PLURAL IS THE FACTORY, singular the note. Each positional argument takes any
// shape a rookery `tags:` does (a string, an array, a dictionary), and VARIADIC so
// `meetings()` is a legal call — a page collecting meetings under no subject of its
// own wants exactly that, and a required parameter would force it to write
// `meetings(none)`.
//
// `today:` IS HERE BECAUSE TYPST HAS NO CLOCK. The rail below is drawn by
// @rookery/timeline's `#timeline-view`, which needs a reference date to tell what
// has happened from what is booked; that package refuses to guess one and panics
// with a message naming the fix. A project stamps its build date in as an input and
// passes it once, here — a per-call `today:` overrides it for one meeting. A
// document that sets its own `#set document(date:)` needs neither.
#let meetings(..names, today: none) = {
  assert(
    names.named().len() == 0,
    message: "@rookery/meetings: #meetings takes the page's tags POSITIONALLY — "
      + "`meetings(TAG_NAME, today: ..)`. Got the named argument(s) "
      + names.named().keys().join(", ")
      + ", which would be silently dropped.",
  )
  let own = names.pos().fold((:), (acc, t) => acc + core._norm-tags(t))
  for (k, _) in own.pairs() { _css-safe(k) }
  // Captured under its own name so the closure's `today:` parameter can default to
  // the factory's without shadowing the value it falls back to.
  let factory-today = today
  let mint = core.tagged-idea(MEETING-KEY)
  (
    tags: none,
    tag: none,
    with: none,
    on: none,
    today: factory-today,
    created: none,
    scheduled: none,
    deadline: none,
    timeline: none,
    ..args,
  ) => {
    let who = _who(with)
    assert(
      on == none or type(on) == datetime,
      message: "@rookery/meetings: `on:` is when the meeting happened and must be a "
        + "datetime — got " + repr(on) + ".",
    )
    // ONE DATE, ONE SPELLING. `on:` sets rookery's own `created:` (see below), so
    // giving both is two answers to when this meeting was — and picking one
    // silently would put a date nobody wrote on the record.
    assert(
      not (on != none and created != none),
      message: "@rookery/meetings: `on:` and `created:` are the same date for a "
        + "meeting — `on:` sets `created:` itself. Give one of them.",
    )
    let log = if timeline == none { (:) } else { timeline }
    if on != none {
      assert(
        OCCURRED-STAGE not in log,
        message: "@rookery/meetings: `on:` writes the `" + OCCURRED-STAGE
          + "` log entry, and `timeline:` already names it. Give one of them.",
      )
      log.insert(OCCURRED-STAGE, on)
    }
    // `#idea`'s OWN POSITIONAL CONTRACT, restated here because the header has to
    // land BEFORE the body and so cannot ride through `..args` blind: one
    // positional is the body, two are the name and the body.
    let pos = args.pos()
    assert(
      pos.len() == 1 or pos.len() == 2,
      message: "@rookery/meetings: #meeting takes a body, optionally preceded by a "
        + "name — `#meeting(<x>)[..]` or `#meeting[..]` — got "
        + str(pos.len())
        + " positional argument(s).",
    )
    let name = if pos.len() == 2 { pos.at(0) } else { none }
    let body = pos.last()
    // Caller's tags first, the page's own on the right — the order that lets a
    // meeting say something the page did not. The two derived keys land on top of
    // both: neither is the caller's free tags nor the page's subject, and nothing
    // else can be writing them.
    let all-tags = core._norm-tags(tags) + core._norm-tags(tag) + own
    if who.len() > 0 { all-tags.insert(MEETING-WITH-KEY, who) }
    all-tags += tl.entries(scheduled: scheduled, deadline: deadline, timeline: log)
    // THE NAME AN UNTITLED MEETING GETS, and `with:`/`on:` are the whole reason it
    // can have one: "Meeting with Finale Doshi-Velez on 10.9.26" is what the note
    // IS, and it is the one thing this factory knows that `#idea`'s own fallback
    // cannot reach — without it a titleless meeting is called by the first sixty
    // characters of its body wherever it is NAMED rather than rendered, which for a
    // meeting is the first thing that happened to come up in it. A meeting that
    // titles itself keeps its own title; nothing here overrides an author.
    //
    // REFS, not the names as text, for `_fields`' first reason: a person's name is
    // typed once, on their own note, and a title built from it by hand would drift
    // the moment that note is renamed. The plain-text projection follows the
    // reference — @rookery/core's `_ref-text` resolves one to the target's own name
    // — so the search index reads "Meeting with Finale Doshi-Velez on 10.9.26".
    //
    // THE DATE IS @rookery/timeline'S OWN SHORT FORM, `tl._fmt-day`, rather than a
    // format spelled out here: the rail under the header writes its dates that way,
    // and a title disagreeing with the rail two lines below it would be this
    // package holding two answers to how it writes a date.
    let stamp = if on == none { none } else { tl._fmt-day(on) }
    let derived = if "title" in args.named() {
      (:)
    } else if who.len() > 0 and stamp != none {
      (title: [Meeting with #_refs(who) on #stamp])
    } else if who.len() > 0 {
      (title: [Meeting with #_refs(who)])
    } else if stamp != none {
      (title: [Meeting on #stamp])
    } else {
      (:)
    }
    // THE RECORD OPENS THE NOTE, above the prose: who was there, then when. It
    // lives in the BODY rather than in a page template for the reason
    // @rookery/core's transclusion forces — a `#window` renders the body and knows
    // nothing about the consuming project's page chrome, so a rail drawn by a
    // template exists on the note's own page and nowhere else.
    //
    // `(:)` AS THE ENTRY, not the note's own row, and that is what keeps the rail
    // one line: `tl.timeline` prepends rookery's `created` to a note's log, and
    // `on:` has just set `created` to the very date the `occurred` entry carries —
    // so passing the row would draw the same day twice.
    let full = {
      if who.len() > 0 { _fields(who) }
      tl.timeline-view((:), all-tags, today: today)
      body
    }
    // `on:` SETS `created:`, which is what makes a meeting's date free to filter
    // and sort by: rookery keeps `created` a ROW field on every `ideas()` row,
    // where a tag value — the log included — costs a `tag-data()` walk to reach.
    // The log entry is what makes the date a TIMELINE event; the row field is what
    // makes it a date. One value, two channels, and no way for them to disagree.
    let resolved-created = if created != none { created } else { on }
    // TWO BRANCHES because a name is POSITIONAL and Typst has no way to pass "no
    // positional argument here": an unnamed meeting must be called with the body
    // alone, not with `none` in front of it, which `#idea` would read as the name.
    if name == none {
      mint(tags: all-tags, created: resolved-created, ..derived, ..args.named(), full)
    } else {
      mint(name, tags: all-tags, created: resolved-created, ..derived, ..args.named(), full)
    }
  }
}

// The bare form, for a project with no page tags to fold in. `today:` per call.
#let meeting = meetings()
```

### `meetings/0.1.0/src/meetings.css`

```css
/* @rookery/meetings — the record a meeting opens with: who was in the room, and
   the rail of when it happened under it.

   Thin on purpose, like every stylesheet in this family: enough that the block
   reads correctly out of the box, and nothing that presumes a page design.

   THE LAYER, and it is not optional. rheo links a PACKAGE's stylesheet AFTER the
   project's own, so on equal specificity this file would win every tie and a
   project could not fix it by writing its rule "later" — there is no later.
   Wrapping everything in a cascade layer inverts that: any UNLAYERED rule in the
   project's CSS beats any layered rule here, whatever its specificity or position.

   THE PROPERTIES. Every colour and size is `var(--x, <default>)`, the default being
   the literal in the var() call. Set one on `.meeting-fields` (or anywhere it
   inherits from) and the block is themed without overriding a rule at all:

     --meeting-fg       a field's value
     --meeting-muted    the label above the block, and a field's name
     --meeting-line     the rules between fields
     --meeting-gap      space between a field's text and the rule under it
     --meeting-gutter   width of the name column

   THE GUTTER MATCHES @rookery/timeline'S RAIL, 7.5em, and the match is the point:
   a meeting draws this block and that rail one after the other, and two adjacent
   tables whose columns start in different places read as two conventions rather
   than one note. The default reads `--timeline-gutter` first, so setting that
   single property lines both up.

   THE SAME MARKUP @rookery/bibtex GIVES A CITATION, deliberately — one gutter, one
   hairline, one label size across the family — but its OWN classes and its own
   copy of the rules, because a project using this package must not have to install
   that one to see a meeting's header. What differs is the spacing: bibtex's block
   is a FOOTER and its gaps are measured for one, which is exactly wrong at the top
   of a note. Here the space goes below the block rather than above it. */
@layer meetings {
  .meeting-fields-head {
    margin: 0.25em 0 0;
    color: var(--meeting-muted, gray);
    text-transform: uppercase;
    letter-spacing: 0.03em;
    font-size: 0.85em;
  }

  /* TWO COLUMNS: the field's name in the gutter, its value to the right. A grid on
     the `<dl>` itself, with each `<dt>`/`<dd>` auto-placed as its own item — so a
     value that wraps to three lines pushes the next row down instead of drifting
     out of column. A grid rather than a flex line, for the reason measured across
     this family: a flex item's basis is only a HYPOTHETICAL size, so a long field
     name would push its value and no two rows would agree where it starts. */
  .meeting-fields {
    display: grid;
    grid-template-columns: var(--meeting-gutter, var(--timeline-gutter, 7.5em)) 1fr;
    column-gap: 0.9rem;
    margin: 0.6rem 0 1.2rem;
    border-top: 1px solid var(--meeting-line, var(--timeline-line, currentColor));
  }

  /* THE RULES BETWEEN FIELDS, one per row, drawn on BOTH cells so the two segments
     abut into a single line across the block. Horizontal only: the field names are
     a label column, not a second column of data. */
  .meeting-fields dt,
  .meeting-fields dd {
    padding: var(--meeting-gap, 0.4rem) 0;
    border-bottom: 1px solid var(--meeting-line, var(--timeline-line, currentColor));
  }

  .meeting-fields dt {
    color: var(--meeting-muted, gray);
    text-transform: uppercase;
    letter-spacing: 0.03em;
    font-size: 0.85em;
  }

  /* `margin: 0` is load-bearing rather than tidy: a browser's default `<dd>`
     carries `margin-inline-start: 40px`, which in a grid cell indents every value
     away from its own column. */
  .meeting-fields dd {
    margin: 0;
    color: var(--meeting-fg, inherit);
  }

  /* A RAIL FOLLOWING THE RECORD carries the block's bottom space instead, so the
     table and the rail read as one header rather than two tables with a gap
     between them. `.timeline` sets `margin: 0.6rem 0 0` itself, which is the space
     ABOVE it; what it has no opinion about is the prose underneath. */
  .meeting-fields:has(+ .timeline) {
    margin-bottom: 0;
  }

  .meeting-fields + .timeline {
    margin-bottom: 1.2rem;
  }
}
```

### `meetings/0.1.0/test/units.typ`

```typst
// Unit fixture: every VALUE `#meeting` derives — the tags it stores, the date it
// sets, the title it synthesizes. No runner: an `assert` failing fails the compile
// with a line number, and a passing compile is the green light. The MARKUP is
// `test/view.typ`'s business, which needs an HTML target this one does not.
#import "/src/lib.typ": *
#import "@rookery/core:0.1.0": idea, ideas, rookery, tag-data
#import "@rookery/timeline:0.1.0": timeline-of

#show: rookery

#let TODAY = datetime(year: 2026, month: 9, day: 10)
#let ON = datetime(year: 2026, month: 9, day: 10)
#let meeting = meetings("lab", today: TODAY)

#idea("doshi-velez-finale", title: [Finale Doshi-Velez])[A person.]

#meeting("dv", with: <doshi-velez-finale>, on: ON)[What was said.]
#meeting("plain")[Nothing declared.]
#meeting("titled", with: <doshi-velez-finale>, on: ON, title: [Own title])[Titled.]
#meeting("dated", on: ON)[Nobody named.]

#context {
  let rows = ideas().map(r => (r.name, r)).to-dict()

  // `on:` SETS `created`, the free row field every date-sorted view reads.
  assert.eq(rows.dv.created, ON, message: "created is " + repr(rows.dv.created))
  assert.eq(rows.dated.created, ON)
  assert.eq(rows.plain.created, none)

  // The synthesized name, as PLAIN TEXT — a ref resolves to its target's own name.
  assert.eq(
    rows.dv.label,
    "Meeting with Finale Doshi-Velez on 10.9.26",
    message: "label is " + repr(rows.dv.label),
  )
  assert.eq(rows.dated.label, "Meeting on 10.9.26")
  // An author's own title wins outright.
  assert.eq(rows.titled.label, "Own title")

  let dv = tag-data().at("idea:dv")
  assert.eq(occurred-of(dv), ON)
  assert.eq(meeting-with-of(dv), ("doshi-velez-finale",))
  assert("meeting" in dv, message: "no meeting tag: " + repr(dv.keys()))
  assert("lab" in dv, message: "the factory's page tag is missing")
  assert.eq(timeline-of(dv).len(), 1)
  assert.eq(timeline-of(dv).first().stage, "occurred")

  // A meeting with neither argument stores neither key and gets no derived title.
  let plain = tag-data().at("idea:plain")
  assert.eq(timeline-of(plain).len(), 0)
  assert.eq(occurred-of(plain), none)
  assert.eq(meeting-with-of(plain), ())
}
```

### `meetings/0.1.0/test/view.typ`

```typst
// Rendered fixture: the MARKUP a meeting opens with, which `test/units.typ`
// cannot see — the record's own `<dl>`, the rail under it, and the order of the
// three blocks inside one card. Asserted by `test/check.sh` against the built
// HTML, because "the rail is above the prose" is a fact about document order.
#import "/src/lib.typ": *
#import "@rookery/core:0.1.0": idea, rookery

#show: rookery

#let TODAY = datetime(year: 2026, month: 9, day: 10)
#let meeting = meetings(today: TODAY)

#idea("doshi-velez-finale", title: [Finale Doshi-Velez])[A person.]

// HAPPENED: the rail's one row is past, and it is the current stage.
#meeting("held", with: <doshi-velez-finale>, on: datetime(year: 2026, month: 9, day: 10))[
  What was said.
]

// BOOKED: a meeting in the diary, drawn as a future row.
#meeting("booked", with: <doshi-velez-finale>, on: datetime(year: 2026, month: 9, day: 24))[
  Not yet held.
]

// NEITHER ARGUMENT: no record block at all, and no rail.
#meeting("bare")[Nothing declared.]
```

### `meetings/0.1.0/test/check.sh`

```bash
#!/usr/bin/env bash
# Asserts on the rendered fixture's OUTPUT, not merely that it compiled.
# `units.typ` covers every value; this covers the markup and, above all, the
# ORDER of the three blocks a meeting's card holds: record, rail, prose.
set -euo pipefail
cd "$(dirname "$0")/.."
H=test/build/view.html
[ -f "$H" ] || { echo "FAIL: no $H — run 'just test' first"; exit 1; }

python3 - "$H" <<'PY'
import re, sys
h = open(sys.argv[1]).read()
fail = 0
def note(msg):
    global fail
    print("FAIL:", msg); fail = 1

# One card per note, sliced on the note's own anchor id.
def card(name):
    i = h.find('id="idea:%s"' % name)
    if i < 0:
        note("no card for %s" % name); return ""
    j = h.find('</figure>', i)
    return h[i:j]

held = card("held")
# 1. THE RECORD IS THERE, with the person as a resolved ref.
if 'class="meeting-fields-head"' not in held or 'class="meeting-fields"' not in held:
    note("held: no record block")
if "Finale Doshi-Velez" not in held:
    note("held: the with: ref did not resolve to the target's title")

# 2. THE ORDER IS RECORD, RAIL, PROSE — the whole point of the block living in
#    the body rather than in a page template.
o_head = held.find('class="meeting-fields-head"')
o_dl = held.find('class="meeting-fields"')
o_rail = held.find('<ol class="timeline">')
o_body = held.find("What was said")
if not (0 < o_head < o_dl < o_rail < o_body):
    note("held: blocks out of order (head %d, dl %d, rail %d, body %d)"
         % (o_head, o_dl, o_rail, o_body))

# 3. ONE ROW, past and current, carrying the date in timeline's short form and
#    the `occurred` stage — and no `created` row doubling the same day.
rows = re.findall(r'<li class="timeline-event ([a-z- ]+)">(.*?)</li>', held, re.S)
if [c for c, _ in rows] != ["timeline-past timeline-current"]:
    note("held: rail rows are %r" % [c for c, _ in rows])
if rows and ("10.9.26" not in rows[0][1] or "occurred" not in rows[0][1]):
    note("held: rail row reads %r" % rows[0][1])

# 4. A MEETING STILL AHEAD is drawn as booked, which is what a reference date buys.
booked = card("booked")
if "timeline-future" not in booked:
    note("booked: a future meeting is not drawn as a future row")

# 5. NEITHER ARGUMENT, NEITHER BLOCK: no record, no rail, no empty apparatus.
bare = card("bare")
if "meeting-fields" in bare or '<ol class="timeline">' in bare:
    note("bare: a meeting with no with:/on: drew a record block anyway")

sys.exit(fail)
PY
echo "view OK"
```

## Do NOT

- Do NOT touch any other package in this repo. `core`, `timeline`, `bibtex`,
  `search`, `todos` and `slipshow` are all unchanged by this bird.
- Do NOT write the package's readme, and do NOT edit the repo's `CLAUDE.md` — a
  separate bird owns both, and it names the files this one creates.
- Do NOT edit `.github/workflows/check.yml`. A separate bird adds the CI step.
- Do NOT add a `package.json`, a `vite.config.js` or a `dist/`. This is a
  pure-Typst package like `core` and `timeline`: the manifest's `entrypoint` and
  `css_stylesheet` point straight at `src/`, and the root `just build` walks every
  nested `Justfile`, so the `default` recipe must stay a no-op echo.
- Do NOT add a rheo demo project. The two fixtures are plain `typst compile`.
- Do NOT symlink anything into `~/.cache/typst/packages/`. The fixtures import
  `/src/lib.typ` by path under `--root .`; only `@rookery/core:0.1.0` and
  `@rookery/timeline:0.1.0` resolve from the cache, and both are already there.
- Do NOT render the `on:` date as a second `<dt>`/`<dd>` row in the record table.
  The rail under the table is where the date goes; a table row saying the same
  thing is the design that was rejected.

## VERIFY

Run all three, from `/home/lox/code/_fcl/rookery`:

1. `cd meetings/0.1.0 && just test` — prints `units OK` then `view OK` and exits
   0. `units.typ` asserts the derived values (created, label, tags, the log);
   `check.sh` asserts the markup and the order of the three blocks.
2. `cd /home/lox/code/_fcl/rookery && just check-versions` — prints
   `check-versions OK across 7 manifests` (6 before this bird).
3. `cd meetings/0.1.0 && just` — prints the buildless echo and exits 0, which is
   what the repo-root `just build` runs for this package.

If step 1 fails inside `#timeline-view` with "this view needs a reference date and
there is none", a fixture lost its `today:` — that is the panic decision 4 above
describes, and the fix is in the fixture, not in the package.