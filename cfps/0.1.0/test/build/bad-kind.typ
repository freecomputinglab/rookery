#import "/src/lib.typ": cfps
#let cfp = cfps(kinds: (
  postdoc: (sort: "job", ladder: (transit: ("submitted",), terminal: ("offered",))),
)).cfp
#cfp("bad-kind", kind: "not-a-real-kind", today: datetime(year: 2026, month: 1, day: 1))[Bad.]
