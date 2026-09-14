// A minimal fixture proving the `cfps(kinds:)` factory and both constructors
// parse and run, and that a settled cfp actually CLOSES through
// @rookery/todos' own mechanism — not merely that it renders.
#import "/src/lib.typ": cfps
#import "@rookery/todos:0.1.0": is-closed
#import "@rookery/core:0.1.0": tag-data

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

// Spot-check: the minted note's own registered tags show it CLOSED — the
// point of Design change 2 — and `cfp-state` reads it as settled.
#context {
  let t = tag-data().at("idea:acme-postdoc-26", default: (:))
  assert(is-closed(t), message: "the settled cfp did not close through @rookery/todos")
  assert.eq(
    cfp-state(t, ladder: (transit: ("submitted",), terminal: ("offered", "rejected")), today: datetime(year: 2026, month: 2, day: 15)),
    "settled",
  )
}
