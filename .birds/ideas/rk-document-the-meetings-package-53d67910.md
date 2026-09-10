---
id: rk-document-the-meetings-package-53d67910
short-id: '5'
title: Document the meetings package
priority: 2
labels:
- docs-meetings
deps:
- blocked-by:rk-add-the-meetings-package-4a1ea2fb
closed: false
---
Write `/home/lox/code/_fcl/rookery/meetings/0.1.0/readme.md`, and add the new
package to the five places `/home/lox/code/_fcl/rookery/CLAUDE.md` enumerates the
family's packages.

**Prerequisite, already satisfied when this bird is startable.** The package
itself is created by the bird this one is blocked by: `meetings/0.1.0/` with
`typst.toml`, `src/lib.typ`, `src/meetings.css`, a `Justfile`, `.gitignore` and
`test/{units.typ,view.typ,check.sh}`. Read `src/lib.typ` before writing a word of
the readme — its header and its comments carry the reasoning this document is a
public restatement of, and nothing here should contradict it.

## What the package is, in one paragraph you can reuse

`@rookery/meetings` gives a rookery a meeting: a note that records WHO was in the
room, WHEN it happened, and what was said. `#meeting` wraps @rookery/core's
`#idea` and adds two arguments — `with:`, which stores the people as idea names
and renders them as refs (so each earns a backlink), and `on:`, which writes an
`occurred` entry into @rookery/timeline's log and sets rookery's own `created:` to
the same date. The record and the rail open the note, above its prose.

## The readme's required sections

Follow the shape every readme in this repo takes (`../../timeline/0.1.0/readme.md`
is the closest model — read its first 120 lines for register and depth). At
minimum:

1. **`# @rookery/meetings`** plus one sentence, then a runnable example:

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

   That note's synthesized title is `Meeting with Finale Doshi-Velez on 10.9.26`
   — VERIFIED, it is asserted in `test/units.typ`. Use exactly that string as the
   example, since it is the one the tests pin.

2. **`## What it owns`** — the flat `meeting` tag, the valued `meeting-with` key,
   and the `occurred` log stage, with the constants that name them
   (`MEETING-KEY`, `MEETING-WITH-KEY`, `OCCURRED-STAGE`). Say what it does NOT
   own: no lifecycle, no ladder, no state to derive, because a meeting is over the
   moment it happened; the log is @rookery/timeline's and `created` is
   @rookery/core's.

3. **`## `with:` — who was in the room`** — accepts a label (`<hagen-blix>`, the
   form to prefer), a bare string, a full `idea:x`, or an array of any of those;
   one name needs no array. Stored as an array of NAMES under `meeting-with`.
   Document the two reasons it renders as refs rather than text: the resolved
   title comes from the person's own note, and the ref earns that person a
   backlink, so their page lists every meeting they were in. Document why it is a
   VALUED KEY rather than a tag per person: a tag key is interpolated into an
   `idea-tag-<key>` class, so every name would have to stay CSS-safe, and a person
   is already a note — a tag would be a second, thinner copy of one.

4. **`## `on:` — when it happened`** — writes the `occurred` log entry AND
   `created:`. Say why both: the log entry makes the date a timeline event, the
   row field makes it free to filter and sort by (rookery keeps `created` on every
   `ideas()` row, where a tag value costs a `tag-data()` walk). Say that `on:`
   together with `created:` is an error, and quote the assert's message. Show
   `occurred-of(tags)` and `meeting-with-of(tags)`, both of which take the tag
   DICTIONARY (`tag-data()`'s per-note value, or an `ideas(values: true)` row's
   `tags-dict`).

5. **`## `today:`, and why there is no clock`** — @rookery/timeline refuses to
   guess a reference date and panics with a message naming the fix; `#meeting`
   passes `today:` straight to `#timeline-view`. It is a `meetings(..)` factory
   argument, overridable per call, and unnecessary in a document that sets its own
   `#set document(date:)`. Quote the panic so a reader who hits it can search for
   it.

6. **`## The record, and where it goes`** — the `.meeting-fields-head` label, the
   `<dl class="meeting-fields">` row, then the rail, then the prose, all INSIDE the
   note's body. Two reasons, both worth stating: a body survives transclusion where
   a page template does not reach, and the record belongs above what was said
   rather than under it. Note that `#timeline-view` is given `(:)` rather than the
   note's row, so `created` is not drawn a second time beside the `occurred` entry
   it duplicates. Note that the block is `html.elem` and so contributes nothing on
   a paged target — the prose still renders, the record does not.

7. **`## The factory`** — `meetings(..tags, today: ..)` returns a `#meeting`
   carrying a page's own tags; plural is the factory, singular the note; it is
   variadic so `meetings()` is legal, and `#meeting` is exported as exactly that.
   Each positional takes any shape a rookery `tags:` does. `tag:` on the returned
   closure is the per-call spelling of the same thing, which is what lets a page
   write `#let meeting = meeting.with(tag: "cassirer")`.

8. **`## Styling it`** — the two classes, and the five custom properties with
   their defaults, copied from `src/meetings.css`'s own header: `--meeting-fg`,
   `--meeting-muted`, `--meeting-line`, `--meeting-gap`, `--meeting-gutter`.
   State that the gutter defaults through `--timeline-gutter` so one property
   lines the record up with the rail, and that everything sits inside
   `@layer meetings` so any unlayered project rule beats it without a specificity
   contest. State that the markup is @rookery/bibtex's citation block by design
   but carries its own classes and its own copy of the rules, so this package has
   no dependency on that one.

9. **`## Requirements`** — Typst 0.15.0 (the `compiler` floor in `typst.toml`),
   rheo 0.6.2 (`min_version`), and `@rookery/core:0.1.0` plus
   `@rookery/timeline:0.1.0`, both imported as aliased modules. Say WHY they are
   aliased: a star import would make this package a second source of `idea`,
   `window` and `rookery`, and a consumer star-importing several rookery packages
   resolves those names by import order — so an undecorated `window` from here
   would shadow @rookery/todos' skinned one.

10. **`## Development`** — `just test` runs both fixtures (`units.typ` for the
    values, `view.typ` plus `check.sh` for the markup and block order); there is
    no build step, `src/` is what ships.

Write it in the repo's register: present tense, declarative, reasons attached to
the decisions they justify, no issue ids, no history of what it replaced.

## The five `CLAUDE.md` edits

All in `/home/lox/code/_fcl/rookery/CLAUDE.md`. Each anchor below is quoted as it
currently reads; change only what is named.

1. Lines 3-6, the family list. It reads `... a dated lifecycle log (`timeline`),
   and todos/epics/a dependency DAG (`todos`)`. Add meetings to it — e.g. `...
   todos/epics/a dependency DAG (`todos`), and dated meeting notes (`meetings`)`.
2. Line 8: `Two of the four (`search`, `todos`) also ship JS` — the count is
   already stale (`bibtex` and `slipshow` are here too and unlisted). Change it to
   `Two of them (`search`, `todos`) also ship JS`, and change nothing else in that
   sentence.
3. Line 101: `Then `just build` the package (skip this for `core`/`timeline`, the
   two dist-less pure-Typst packages` — becomes `core`/`timeline`/`meetings`, and
   `the three dist-less pure-Typst packages`.
4. Line 203: ``core` and `timeline` are pure Typst (+ CSS)` — becomes ``core`,
   `timeline` and `meetings` are pure Typst (+ CSS)`.
5. Line 229: `ADDS `dist/` on top of it when the build produced one — so
   `core`/`timeline` ship their `src/` directly` — add `meetings` to that pair.

## Do NOT

- Do NOT change any file under `meetings/0.1.0/` other than adding `readme.md`.
  The manifest, the source, the stylesheet, the Justfile and the two fixtures are
  another bird's and are already verified.
- Do NOT rewrite unrelated parts of `CLAUDE.md`. Five anchors, named above.
- Do NOT document arguments the package does not have. `#meeting` takes exactly
  `tags:`, `tag:`, `with:`, `on:`, `today:`, `created:`, `scheduled:`,
  `deadline:`, `timeline:`, an optional positional name and a positional body,
  plus whatever `#idea` itself takes through the sink (`title:`, `level:`,
  `show-tags:` and the rest). Check `src/lib.typ` rather than guessing.
- Do NOT invent a `#meetings-view`, an index or a corpus-wide list. There is no
  such function in 0.1.0, and a readme promising one is worse than no readme.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery && just check-versions` — still prints
   `check-versions OK across 7 manifests`. This is the check that matters for a
   readme: it greps every `@rookery/<pkg>:<x.y.z>` spec in the package directory,
   readme included, and fails if one names this package at a version other than
   `0.1.0` or another package at a version that is not in the repo.
2. `cd /home/lox/code/_fcl/rookery/meetings/0.1.0 && just test` — still green
   (`units OK`, `view OK`). It must be, since this bird changes no source; run it
   to prove nothing was edited by accident.
3. Every example in the readme that imports `@rookery/meetings` names `0.1.0`,
   and the synthesized-title example reads exactly
   `Meeting with Finale Doshi-Velez on 10.9.26` — the string `test/units.typ`
   asserts.