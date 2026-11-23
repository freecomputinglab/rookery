// @rookery/timeline — a dated log for rookery notes.
//
// A note's temporal planning, contributed through @rookery/core's TAG
// DICTIONARY rather than through a wrapper around `#idea`. The whole interface
// is a fragment builder you merge into a `tags:` argument:
//
//   #import "@rookery/timeline:0.1.1": dates
//   #idea("ship", tags: timeline-tags(deadline: datetime(year: 2026, month: 9, day: 1)))[..]
//
// THAT SHAPE IS THE POINT. The CORE of this package imports @rookery/core not
// at all, and @rookery/core knows nothing of it — a tag fragment is a plain
// dictionary, so composition needs no import relationship in either direction.
// Any package, and any hand-written `#idea`, can use it. `dated(mint)` keeps
// that true for the decorator too, by taking the minting function as an
// ARGUMENT.
//
// WHAT IT OWNS: a note's DATED EVENTS, as one ordered log — org-mode's LOGBOOK.
// `scheduled` (when you mean to work on it) and `deadline` (a hard date) are
// RESERVED STAGE NAMES inside that log rather than slots beside it, so one
// mechanism carries arbitrarily complex lifecycles without this package naming
// any of their states.
//
// WHAT IT DOES NOT OWN, deliberately:
//
//   - `created`. Rookery core resolves and stores it and ships it on every
//     `ideas()` row. This package READS it (`created-of` below) rather than
//     keeping a second copy that could disagree — and core keeping it a ROW field
//     rather than a tag value is what makes filtering by date free, since a tag
//     value costs a `tag-data()` walk to reach.
//   - a STAGE VOCABULARY beyond the three reserved names. Whether `accepted` ends
//     a process or is the middle of it depends on words a consumer owns, so
//     `is-settled`/`rung`/`next-stage` take a ladder as a parameter. Status
//     transitions likewise: @rookery/todos owns `activated`.
//
//   `updated` is neither owned nor read; core ships no such field.
//   `updated-of` DERIVES it: the log's last entry, else `created`.
//
// THERE IS NO WALL CLOCK, and this constrains the whole package. MEASURED at
// typst 0.15.1: `datetime.today().hour()` is `none`, and `SOURCE_DATE_EPOCH`
// (which this repo's own devShell sets, to 315532800) makes `datetime.today()`
// return 1980-01-01 rather than the real date.
// IT FAILS SILENTLY — a wrong date, not an error. So:
//
//   - every date is author-supplied; nothing here is auto-stamped
//   - NO FUNCTION IN THIS PACKAGE MAY CALL `datetime.today()`
//   - a predicate needing a "now" takes an explicit `today:`, falling back to
//     the document's own `#set document(date:)`, and panics rather than guess
//
// This package reads no rheo context, no `sys.inputs` and no state, and ships
// no JavaScript. TWO functions are not pure functions of their arguments,
// and they are the two that DRAW something:
//
//   `#timeline-view` (`view.typ`) emits HTML — one note's log as a vertical rail —
//   which is why this package ships a stylesheet at all.
//
//   `#timeline-upcoming` (`upcoming.typ`) emits HTML AND READS THE NOTE REGISTRY, through
//   rookery's `ideas()`, because it draws one row per note across a whole corpus
//   and a caller cannot hand it that corpus as an argument. That is a real
//   widening of what this package touches, stated here rather than buried: it is
//   the same thing @rookery/todos' own views do, and nothing else here
//   follows it.

#import "fragment.typ": *
#import "read.typ": *
#import "when.typ": *
#import "ladder.typ": *
#import "view.typ": *
#import "upcoming.typ": *

// THE PATTERN. If you use plain rookery you import `idea`, `window` and the rest
// from rookery. If you use this package you import those SAME names from HERE
// instead, and get versions that take this package's date arguments. A skin over
// the default rather than a sidecar beside it.
//
//   #import "@rookery/timeline:0.1.1": idea, window, rookery
//   #idea("ship", deadline: d, timeline: (submitted: d2))[..]
//
// HOW IT WORKS:
//
//   1. the star-import below RE-EXPORTS every rookery name to this module's own
//      consumers, so `window`, `ideas`, `tag-data`, `rookery` and the rest pass
//      through untouched and this file does not have to list them;
//   2. the aliased import keeps the ORIGINALS reachable, which is what lets a
//      decorated version call the thing it decorates;
//   3. a later top-level `#let` SHADOWS a star-imported name, so what this module
//      exports is the decorated one.
//
// WHAT IS OVERRIDDEN, and it is only this one. Everything else is rookery's,
// unchanged, and a consumer importing it from here gets exactly what it would get
// from there.
#import "@rookery/core:0.1.1": *
#import "@rookery/core:0.1.1" as _rk

// A rookery note that also takes `timeline:`/`scheduled:`/`deadline:`. Its
// `..args` sink forwards core's merging `tag:`/`base-tags:` arguments
// untouched, so a consumer builds a family of its own directly over this
// skin — `idea.with(base-tags: "submission")` — and gets the date arguments
// together with the tag family, with nothing else to wrap.
#let idea = dated(_rk.idea)
