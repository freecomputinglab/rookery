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
