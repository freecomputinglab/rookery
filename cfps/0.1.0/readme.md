# @rookery/cfps

A venue and its calls for [`@rookery/core`](../../core/0.1.0): a durable place
things are heard from, and one round of it — a deadline, a portal, and what
happened when it was answered.

```typst
#import "@rookery/core:0.1.0": rookery
#import "@rookery/cfps:0.1.0": cfps
#show: rookery

#let TODAY = datetime(year: 2026, month: 6, day: 1)
#let (venue, cfp, cfp-state, panel) = cfps(kinds: (
  postdoc: (sort: "job", ladder: (transit: ("submitted",), terminal: ("offered", "rejected"))),
))

#venue("acme", title: [Acme University])[A programme that runs every year.]

#cfp(
  "acme-postdoc-26",
  venue: <acme>,
  kind: "postdoc",
  deadline: datetime(year: 2026, month: 1, day: 1),
  today: TODAY,
)[A round that lapsed with nothing sent.]

#cfp(
  "acme-postdoc-25",
  venue: <acme>,
  kind: "postdoc",
  deadline: datetime(year: 2025, month: 1, day: 1),
  timeline: (submitted: datetime(year: 2024, month: 12, day: 1), offered: datetime(year: 2025, month: 2, day: 1)),
  today: TODAY,
)[A round that was answered, and settled.]

#panel(state: "settled", today: TODAY) // -> lists only "acme-postdoc-25"
```

## A call and its answer are one note

A CFP is one round of a venue — a call for papers or applications, together
with whatever came back. The two are never two different attempts at two
different things; they are one attempt looked at before and after, so
keeping them as two separate notes would mean two places a deadline or a
decision could disagree, and a backlink graph where "what became of this" is
an edge to walk rather than a fact already on the note. `#cfp` folds the two
into one note instead, and its own log — the ordinary dated history
`@rookery/timeline` already gives every note — is where the whole story,
wire to verdict, actually lives.

A VENUE is the other half, and it is deliberately thin: a durable place a call
recurs from — a programme, a conference series, a journal — carrying no dates
and closing nothing. Two rounds of one programme are two `#cfp`s sharing one
`#venue`.

## `cfps(kinds:)` — the factory

`kind`/`ladder` are not this package's vocabulary, so `cfps(..)` is a
factory: bind it to a caller's own once, and it hands back the four names
that vocabulary makes possible.

```typst
#let (venue, cfp, cfp-state, panel) = cfps(kinds: (
  job: (
    sort: "job",
    ladder: (transit: ("submitted", "interview"), terminal: ("offered", "rejected", "dropped")),
  ),
  journal: (
    sort: "journal",
    ladder: (transit: ("submitted", "review-*"), terminal: ("accepted", "desk-rejected")),
  ),
))
```

`kinds:` is a dictionary of kind name to `(sort:, ladder:)`, where `ladder:`
is an ordinary `@rookery/timeline` ladder — `transit:` and `terminal:` arrays
of stage names, a trailing `-*` naming a FAMILY of stages (`review-*` matches
`review-1`, `review-2`, ..., see that package's own `ladder.typ`). A bad
`kinds:` fails at this call, not on whichever `#cfp` happens to name a bad
kind first, and `#cfp`'s own `kind:` argument is checked against it the same
way:

```typst
#cfp("x", kind: "grant", ..)  // grant is not job or journal
```

```
@rookery/cfps: #cfp's `kind` must be one of ("job", "journal") — got "grant".
```

A worked round-trip, minting both halves and narrowing `panel:` to what has
actually settled:

```typst
#let (venue, cfp, cfp-state, panel) = cfps(kinds: (
  postdoc: (sort: "job", ladder: (transit: ("submitted",), terminal: ("offered", "rejected"))),
))

#let TODAY = datetime(year: 2026, month: 6, day: 1)
#venue("eth", title: [ETH Zürich])[A school.]

#cfp("eth-postdoc-26", venue: <eth>, kind: "postdoc", deadline: datetime(year: 2026, month: 3, day: 1), today: TODAY)[
  Sent, nothing back yet.
]
#cfp(
  "eth-postdoc-25",
  venue: <eth>,
  kind: "postdoc",
  deadline: datetime(year: 2025, month: 3, day: 1),
  timeline: (submitted: datetime(year: 2025, month: 1, day: 1), offered: datetime(year: 2025, month: 4, day: 1)),
  today: TODAY,
)[Answered, and settled.]

#panel(state: "settled", today: TODAY)
```

The panel above lists exactly `eth-postdoc-25` — the still-open `26` round
is filtered out by `state: "settled"`.

## Why `kind`/`ladder` are caller-supplied

No package can know that `offered` ends a job application while `accepted`
ends a conference submission and is the middle of a journal's review. That
vocabulary is the caller's, project by project, the same reason
[`@rookery/timeline`'s own `ladder.typ`](../../timeline/0.1.0/src/ladder.typ)
takes a ladder as a parameter rather than owning one — see that file's header
for the argument in full; this package just inherits it, one level up.

## `#cfp` IS a `#todo`

`#cfp` is built on [`@rookery/todos`](../../todos/0.1.0)' own `todo(..)`, not
a bare tagged note, and that buys a reader two things for free. A cfp shows
up in `#todo-table` with no separate wiring — an open call is
work outstanding, the same as any other todo — and it closes CORRECTLY the
moment it is answered or its deadline lapses: `#cfp` computes the real close
date itself (the earliest real answer, or the deadline if it lapsed
unanswered) and passes it as `todo(..)`'s `done:`, a real dated log entry
rather than a flag. `is-closed`, `#todo-table`, a consumer's own worklists —
everything reading that log agrees, because there is only the one log to
read. `priority:` is `@rookery/todos`' own as well, unchanged: a project
already running that package's worklists gets its cfps sorted into them
automatically, at whatever priority they were given.

## Integrating `#window`

A site that wraps `@rookery/todos`' `#window` with its own hiding logic —
transcluding a cfp but hiding it when, say, the real answer was a rejection —
has one thing to get right: that wrapper must pass `closed: true` through on
whichever branch decides to SHOW the note. `@rookery/todos`' own `#window`
independently hides any closed todo unless told otherwise, and every `#cfp`
now closes on either a real answer or a lapsed deadline — so a site's own
hiding decision will otherwise be silently overridden by that second, unrelated
check the moment the deadline passes. This is not a bug in either package; it
is what composing two independent "should this be visible" rules does, and
it is worth knowing before wrapping `#window` around a `#cfp` for the first
time rather than rediscovering it on a live site.

## `panel:` — the rounds table

`panel(state:, tags:, countdown:, today:)` draws one row per call — `when |
title | school | verdict` — in date order, bound to the same `kinds`/ladder
`cfp` was:

```typst
#panel(state: ("open", "in-flight"), countdown: true, today: TODAY)
```

`state:` narrows by the same four states `cfp-state` derives (below);
`tags:` narrows further by whatever grouping the caller's own site uses (a
cycle, a kind not already covered by `state:`); `countdown:` washes the date
cell by how many days remain, the same three-week band `@rookery/todos`'
`#todo-table` reads. On a paged target the same rows draw as a plain list —
there is no grid to align there.

## The four states, and why they are net of the reserved stages

`cfp-state(tags, ladder:, today:)` returns one of `"watching"` (nothing
announced at all), `"open"` (a wire is out, unanswered, not yet lapsed),
`"in-flight"` (a real answer is in and it is a transit rung), or `"settled"`
(a real answer is in and it is a terminal rung). All four are read off the
note's log with `deadline`/`scheduled`/`closed` stripped first
(`real-stage-of` does the stripping; `cfp-state` is the four-state
reading on top of it) — because a raw, unfiltered log answers a different
question than the one a caller is actually asking, in two ways that bit the
site this package was ported from:

- **A lapsed, unanswered call is `"open"`, not `"in-flight"`.** Read raw, an
  overdue `deadline` is the LATEST reached entry, and nothing in it looks
  like a transit rung — so a naive reading calls it in flight when nothing
  was ever sent.
- **A real answer dated before the deadline still counts.** A call dropped
  early — its `timeline:` reaching a terminal stage before the deadline
  itself arrives — reads raw as still "deadline", the later of the two dates,
  masking the actual answer.

## What it owns

- `venue`/`venue-<kind>`, flat tags marking a note as a venue, and one per
  call kind it hosts.
- `venue-call` (a venue's own standing submissions page) and `venue-school`
  (an array of host-institution names, for a joint programme).
- `cfp`, the flat marker `panel:` filters rows on — stamped directly in
  `#cfp`'s own tags rather than through a `tagged-idea(..)` call, since
  `#cfp` mints through `@rookery/todos`' `todo(..)`, which already claims the
  `todo` tag for itself.
- `cfp-venue` (the venue's name, valued, optional), `cfp-id` (the call's own
  name, so a tag-only filter can identify its row), `submission-apply` (this
  round's own portal, distinct from a venue's standing `venue-call`),
  `submission-work` (the matched application's own path or URL), and
  `submission-estimated` (a flat marker for a body carried over from a past
  cycle's call rather than read off this round's own).

## Requirements

- Typst 0.15.0 or later (`typst.toml`'s `compiler` floor).
- rheo 0.6.2 or later (`min_version`).
- [`@rookery/core:0.1.0`](../../core/0.1.0),
  [`@rookery/timeline:0.1.0`](../../timeline/0.1.0) and
  [`@rookery/todos:0.1.0`](../../todos/0.1.0). All three are hard imports —
  `#cfp` is a skin on `@rookery/todos`' own `todo(..)`, which is itself a
  skin on `@rookery/timeline`'s dated notes.

## Development

```sh
cd cfps/0.1.0
just test
```

Two fixtures, no build step: `test/units.typ` asserts every value the
package's constructors derive — the four-state ladder logic, the tags `#cfp`
stamps, that closing is a real log entry rather than a flag — and
`test/view.typ` plus `test/check.sh` assert the rendered markup: that the rail
draws from `deadline:` alone as readily as from a full `timeline:`, the
opportunity table's position relative to it, the venue backlink, and
`panel:`'s row classes. `typst.toml`'s `entrypoint` points straight at
`src/lib.typ`, so `src/` is what ships and an edit takes effect immediately.

## Future work

No `demo/` project ships with this package yet — a worked `rheo compile`
target, the way `@rookery/todos`' demo exercises all six of its views, would
be a reasonable thing to add for the next round of work on it.
