// Rendered fixture: the MARKUP `#venue`/`#cfp`/`panel:` draw, which
// `test/units.typ` cannot see — that the in-body rail renders whenever ANY of
// `deadline`/`scheduled`/`timeline:` is given (not only `timeline:`), that the
// opportunity table lands below the title and above that rail, that a venue
// backlink appears only when `venue:` was given, and that `panel:`'s rows carry
// the right classes for a settled, an open, and a watching call. Asserted by
// `test/check.sh` against the built HTML, because document order and CSS class
// are facts about the markup, not about a value.
#import "/src/lib.typ": *
#import "@rookery/core:0.1.1": rookery

#show: rookery

#let TODAY = datetime(year: 2026, month: 6, day: 15)
#let (venue, cfp, cfp-state, panel) = cfps(kinds: (
  postdoc: (sort: "job", ladder: (transit: ("submitted",), terminal: ("offered", "rejected"))),
))

#venue("acme", title: [Acme University], call: "https://acme.example/apply")[The standing call.]

// DEADLINE ONLY: no `timeline:` at all — the rail still draws, from `deadline:`
// alone. OPEN: the deadline is still ahead.
#cfp(
  "acme-deadline-only",
  venue: <acme>,
  kind: "postdoc",
  deadline: datetime(year: 2026, month: 8, day: 1),
  today: TODAY,
)[
  Only a deadline, nothing sent.
]

// SETTLED, and carries `work:` — the one fixture exercising the opportunity
// table, so its order relative to the rail and the title can be checked.
#cfp(
  "acme-settled",
  venue: <acme>,
  kind: "postdoc",
  deadline: datetime(year: 2026, month: 1, day: 1),
  timeline: (
    submitted: datetime(year: 2025, month: 12, day: 1),
    offered: datetime(year: 2026, month: 2, day: 1),
  ),
  work: "acme-postdoc-application.pdf",
  today: TODAY,
)[
  Answered and settled.
]

// WATCHING: no venue, no deadline, no scheduled, no timeline — nothing
// announced yet, and no backlink to draw since there is no venue.
#cfp("no-venue-watching", kind: "postdoc", today: TODAY)[
  Nobody named, nothing heard.
]

#panel(state: "settled", today: TODAY)
#panel(state: "open", today: TODAY)
#panel(state: "watching", today: TODAY)
// EMPTY: nothing in this fixture ever reaches "in-flight".
#panel(state: "in-flight", today: TODAY)
