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
#idea("hagen-blix", title: [Hagen Blix])[Another person.]

#meeting("dv", with: <doshi-velez-finale>, on: ON)[What was said.]
#meeting("plain")[Nothing declared.]
#meeting("titled", with: <doshi-velez-finale>, on: ON, title: [Own title])[Titled.]
#meeting("dated", on: ON)[Nobody named.]

// Dateless, untitled, unnamed: the case that used to collide on
// `idea:meeting-with` whatever the participants were.
#meeting(with: <doshi-velez-finale>)[No name, no date, one participant.]
#meeting(with: <hagen-blix>)[No name, no date, a different participant.]
// Dated and unnamed, WITH participants: the dated branch keeps today's
// title-derived id, untouched by the dateless auto-name above.
#meeting(with: <doshi-velez-finale>, on: ON)[Dated, unnamed, same participant.]

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

  // A dateless, untitled, unnamed meeting mints an id from its participants —
  // not the fixed `idea:meeting-with` every such meeting used to collide on.
  // Reaching each by its derived id (rather than erroring at compile time on
  // a duplicate) is itself proof the two below did not collide.
  let dv-auto = tag-data().at("idea:meeting-with-doshi-velez-finale")
  assert.eq(meeting-with-of(dv-auto), ("doshi-velez-finale",))
  let blix-auto = tag-data().at("idea:meeting-with-hagen-blix")
  assert.eq(meeting-with-of(blix-auto), ("hagen-blix",))

  // The DATED branch (`on:` given) keeps today's title-derived id, unchanged
  // by this fix — core's id-slug renders a `ref` as empty text, so the id
  // carries only the date, not the participant (`meeting-with-of` below is
  // what actually distinguishes participants for the dated case).
  let dated-auto = tag-data().at("idea:meeting-with-on-10-9-26")
  assert.eq(meeting-with-of(dated-auto), ("doshi-velez-finale",))
  assert.eq(occurred-of(dated-auto), ON)
}
