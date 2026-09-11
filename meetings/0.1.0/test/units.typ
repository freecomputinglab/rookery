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
