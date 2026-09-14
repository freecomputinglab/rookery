// A minimal fixture proving the `cfps(kinds:)` factory and both constructors
// parse and run, that a settled cfp actually CLOSES through @rookery/todos'
// own mechanism — not merely that it renders — and that `panel:` draws both a
// populated rounds table and its empty state.
#import "/src/lib.typ": cfps
#import "@rookery/todos:0.1.0": is-closed
#import "@rookery/core:0.1.0": tag-data

#let TODAY = datetime(year: 2026, month: 2, day: 15)

#let (venue, cfp, cfp-state, panel) = cfps(kinds: (
  postdoc: (sort: "job", ladder: (transit: ("submitted",), terminal: ("offered", "rejected"))),
))

#venue("acme", title: [Acme University], school: "eth")[A test venue.]
#venue("eth", title: [ETH Zürich])[A test school.]

// Answered and settled.
#cfp(
  "acme-postdoc-26",
  venue: <acme>,
  kind: "postdoc",
  deadline: datetime(year: 2026, month: 1, day: 1),
  timeline: (submitted: datetime(year: 2025, month: 12, day: 20), offered: datetime(year: 2026, month: 2, day: 1)),
  today: TODAY,
)[A test call, answered and settled.]

// Open: a deadline still ahead, nothing sent yet.
#cfp(
  "acme-postdoc-27",
  venue: <acme>,
  kind: "postdoc",
  deadline: datetime(year: 2026, month: 6, day: 1),
  today: TODAY,
)[A test call, still open.]

// Watching: no deadline, no scheduled date, no timeline at all — nothing
// announced yet.
#cfp(
  "acme-postdoc-28",
  venue: <acme>,
  kind: "postdoc",
  today: TODAY,
)[A test call nobody has heard from yet.]

// Spot-check: the minted note's own registered tags show it CLOSED — the
// point of Design change 2 — and `cfp-state` reads it as settled.
#context {
  let t = tag-data().at("idea:acme-postdoc-26", default: (:))
  assert(is-closed(t), message: "the settled cfp did not close through @rookery/todos")
  assert.eq(
    cfp-state(t, ladder: (transit: ("submitted",), terminal: ("offered", "rejected")), today: TODAY),
    "settled",
  )
}

// The rounds table: every state populated runs both the row-mapping and the
// HTML-rendering halves (dated + undated rows, a school column, a kind badge,
// a settled-stage badge).
#panel(state: ("open", "in-flight", "settled", "watching"), countdown: true, today: TODAY)

// The same panel, narrowed to a state none of the fixture's calls are in —
// the empty-state branch.
#panel(state: "in-flight", today: TODAY)
