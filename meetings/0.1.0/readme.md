# @rookery/meetings

A meeting note for [`@rookery/core`](../../core/0.1.0): who was in the room, when
it happened, and what was said.

```typst
#import "@rookery/core:0.1.0": idea, rookery
#import "@rookery/meetings:0.1.0": meeting

#show: rookery

#idea("doshi-velez-finale", title: [Finale Doshi-Velez])[A person.]

#meeting(
  <doshi-velez-26-9-10>,
  with: <doshi-velez-finale>,
  on: datetime(year: 2026, month: 9, day: 10),
  today: datetime(year: 2026, month: 9, day: 10),
)[
  What was said.
]
```

That note's synthesized title is `Meeting with Finale Doshi-Velez on 10.9.26` —
asserted in `test/units.typ`. `#meeting` wraps `#idea` and adds exactly two
arguments, `with:` and `on:`, and both feed that title: they are the one thing
this package knows about a meeting that `#idea`'s own untitled-note fallback
cannot reach, which otherwise names a meeting by the first sixty characters of
whatever happened to be typed first in its body.

## What it owns

Three keys, and nothing that could grow into a fourth:

- `meeting`, a flat tag (the constant `MEETING-KEY`), so `tags:meeting` finds
  every meeting across a rookery with an ordinary tag query.
- `meeting-with`, a valued tag (`MEETING-WITH-KEY`) holding the array of names
  `with:` resolved.
- `occurred`, a log stage (`OCCURRED-STAGE`) that `on:` writes into
  [`@rookery/timeline`](../../timeline/0.1.0)'s per-note log.

What it deliberately does not own is a lifecycle. A todo moves through stages
because its future is still open; a meeting is finished the moment it is
minted, so there is no ladder here, no "next stage", nothing to derive from one
— the whole package is two facts recorded once. The log the `occurred` entry
lives in is timeline's, not this package's own invention, and the `created`
date `on:` also sets (below) is core's own row field. `#meeting` writes into
both, and owns neither.

`meeting-with-of(tags)` and `occurred-of(tags)` read the two derived keys back.
Both take the tag DICTIONARY — `tag-data()`'s per-note value, or an
`ideas(values: true)` row's `tags-dict` — so building a view over meetings costs
no registry read of its own:

```typst
#import "@rookery/core:0.1.0": tag-data
#import "@rookery/meetings:0.1.0": meeting-with-of, occurred-of

#context {
  let t = tag-data().at("idea:doshi-velez-26-9-10")
  occurred-of(t)      // datetime(2026, 9, 10)
  meeting-with-of(t)  // ("doshi-velez-finale",)
}
```

## `with:` — who was in the room

`with:` takes whatever a rookery reference can be written as: a label
(`<hagen-blix>`, the form to prefer, since it reads on the page as the
reference it is), a bare string (`"hagen-blix"`), or a full id
(`"idea:hagen-blix"`) — and an array of any mixture of those, for a meeting
with more than one person in it. One name needs no array at all;
`with: <hagen-blix>` and `with: (<hagen-blix>,)` store the same thing. Every
form normalizes to the bare name, and that array of names is what
`meeting-with` stores.

Rendered, each name becomes its own `ref` rather than plain text — "With
#ref(<hagen-blix>)", not "With Hagen Blix" typed by hand — for two reasons,
both load-bearing. First, a `ref` takes the RESOLVED TITLE of the note it
points at, so a person's name is typed once, on their own note, and the header
never drifts out of sync with a rename the way a hand-typed name would.
Second, a `ref` earns that person a BACKLINK: their own page ends up listing
every meeting they were in, for free, as a consequence of nothing more than
being named here.

`meeting-with` is a valued key rather than a tag per attendee, and the
alternative is worse for a concrete reason: a tag key is interpolated into an
`idea-tag-<key>` class, so every name that ever walked into a room would have
to stay CSS-safe forever after. A person is also already a note — a tag would
be a second, thinner copy of the one that already exists on their own page. A
valued key keeps that page the only place a person is described, while
`tags:meeting-with` still answers "which meetings record who was there" as a
plain presence query.

## `on:` — when it happened

`on:` is a `datetime`, and it is written to two places for two different
reasons. It writes the `occurred` log entry, which is what makes the date a
TIMELINE event — the thing `@rookery/timeline`'s rail can draw a row for and
sort among a note's other entries. It also sets rookery's own `created:` to the
same date, which is what makes the date free to filter and sort by: rookery
keeps `created` as a plain ROW field on every `ideas()` row, where a value
living inside a tag — the log included — costs a `tag-data()` walk to reach.
One value, two channels, and no way for them to disagree, because `on:` is the
only place either is set from.

That means giving both `on:` and `created:` is two answers to the same
question, and `#meeting` rejects it outright:

```
@rookery/meetings: `on:` and `created:` are the same date for a meeting — `on:` sets `created:` itself. Give one of them.
```

The same logic applies to the log directly: if a caller already writes an
`occurred` entry through `timeline:`, adding `on:` on top of it would be a
second attempt to say when the meeting happened, so that combination is
rejected too:

```
@rookery/meetings: `on:` writes the `occurred` log entry, and `timeline:` already names it. Give one of them.
```

## `today:`, and why there is no clock

`#meeting` draws a rail under its record by calling `@rookery/timeline`'s
`#timeline-view`, which needs a reference date to say what has already
happened versus what is still booked. Typst has no wall clock, and timeline
will not guess one on your behalf — with none available it panics, naming both
fixes:

```
@rookery/timeline: this view needs a reference date and there is none. Typst has no wall clock — `datetime.today()` returns 1980-01-01 under a reproducible build — so pass one explicitly, e.g. `today: datetime(year: 2026, month: 8, day: 25)`, or set the document's own date with `#set document(date: ..)`.
```

`#meeting` passes its own `today:` straight through to that call. It is a
`meetings(..)` FACTORY argument (below) — a project stamps its build date in
once, at the factory call, rather than at every meeting — and it is
overridable per call, for the rare meeting that needs a different reference
date than the rest of the page. A document that already sets its own
`#set document(date:)` needs neither: `#timeline-view` falls back to that
before it panics.

## The record, and where it goes

A meeting opens with a small record, not a sentence. `Meeting` labels the block
(a `<div class="meeting-fields-head">`), then a `<dl class="meeting-fields">`
holds one row, `With` against the comma-joined refs from `with:`. The rail
follows directly under it, then the body — record, rail, prose, in that exact
order, which `test/check.sh` asserts against the built markup.

Both the record and the rail live INSIDE the note's body, not in a page
template, for a reason `@rookery/core`'s transclusion forces: a `#window`
renders a note's body wherever it transcludes it, and knows nothing about the
consuming project's page chrome — a rail drawn by a template would exist on
the note's own page and nowhere else, which defeats the point of a note that
can appear inside another one. Putting the record in the body also puts it
where it belongs relative to what was said: a meeting's record is what the
note IS, and prose about what happened should not have to open by restating
who was there.

The rail is drawn with `tl.timeline-view((:), all-tags, today: today)` — an
empty entry, not the note's own row. `#timeline-view` prepends rookery's
`created` to whatever entry it is given, and `on:` has already set `created`
to the very date the `occurred` entry carries; passing the row would draw that
one day twice.

The whole block is built with `html.elem`, which contributes nothing at all on
a paged target — the label, the `<dl>`, none of it exists there. A meeting's
prose still renders under a PDF export; its record does not, the same trade
every rendered view in this family makes.

## The factory

`meetings(..tags, today: ..)` returns a `#meeting` that carries a page's own
tags into every call:

```typst
#import "@rookery/meetings:0.1.0": meetings

#let meeting = meetings("digital-theory-lab", today: TODAY)
#meeting(<blix-27-8-26>, with: <hagen-blix>, on: d)[..]
```

Plural is the factory, singular the note the factory mints — and `#meeting`
itself is exactly `meetings()` called with no arguments, exported under that
name for a project with no page tags of its own to fold in.

Each positional argument to `meetings(..)` takes any shape a rookery `tags:`
does — a string, an array, a dictionary — and the call is variadic so
`meetings()` with none at all is legal: a page collecting meetings under no
subject of its own should not be forced to write `meetings(none)`.

The returned closure carries its own `tag:` parameter, the per-call spelling of
the same idea, and that is what lets a page fix one extra tag onto every
meeting it mints from then on, using Typst's own partial application rather
than anything this package adds:

```typst
#let meeting = meetings(today: TODAY).with(tag: "cassirer")
```

## Styling it

Two classes carry the record: `.meeting-fields-head` for the label, and
`.meeting-fields` for the `<dl>` itself. Five custom properties theme it, each
`var(--x, <default>)` so setting one is enough — no rule to override:

| property | default |
| --- | --- |
| `--meeting-fg` | a field's value text — `inherit` |
| `--meeting-muted` | the label and a field's name — `gray` |
| `--meeting-line` | the rules between fields — `var(--timeline-line, currentColor)` |
| `--meeting-gap` | space between a field's text and the rule under it — `0.4rem` |
| `--meeting-gutter` | width of the name column — `var(--timeline-gutter, 7.5em)` |

`--meeting-gutter` reads `--timeline-gutter` first rather than defaulting to
`7.5em` on its own, and that is the point: a meeting draws this block and
timeline's rail one after another, and setting the single `--timeline-gutter`
property lines both columns up. Two adjacent tables starting in different
places would read as two conventions rather than one note.

Everything sits inside `@layer meetings`, so any unlayered rule in a
consuming project's own stylesheet beats it regardless of specificity — rheo
links a package's stylesheet after the project's own, so without a layer this
file would win every tie a project could not otherwise break.

The markup is `@rookery/bibtex`'s citation block by design — one gutter, one
hairline, one label size across the family that draws this shape — but with
its own classes and its own copy of the rules, so a project using this package
has no dependency on that one and nothing to install to see a meeting's
header.

## Requirements

- Typst 0.15.0 or later (`typst.toml`'s `compiler` floor).
- rheo 0.6.2 or later (`min_version`).
- [`@rookery/core:0.1.0`](../../core/0.1.0) and
  [`@rookery/timeline:0.1.0`](../../timeline/0.1.0), both imported as aliased
  modules (`import ... as core`, `import ... as tl`) rather than star-imported.
  A Typst module re-exports every top-level binding it holds, star-imported
  ones included — so an unaliased import here would make this package a
  second source of `idea`, `window` and `rookery`, and a project star-importing
  several rookery packages resolves a name like that by IMPORT ORDER. An
  undecorated `window` arriving from this package would silently shadow
  `@rookery/todos`' own skinned one.

## Development

```sh
cd meetings/0.1.0
just test
```

Two fixtures, no build step: `test/units.typ` asserts every value `#meeting`
derives — the tags it stores, the date it sets, the title it synthesizes —
and `test/view.typ` plus `test/check.sh` assert the rendered markup and the
record/rail/prose order. `typst.toml`'s `entrypoint` points straight at
`src/lib.typ`, so `src/` is what ships and an edit takes effect immediately.
