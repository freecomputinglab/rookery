#import "lib.typ": demo, idea, note, tagged-idea
#import "@rookery/core:0.1.0": ideas, ideas-outline, tag-index, tag-value, tags-of, window

#show: demo

= Tag surfaces

// `#todo` is not a package export — `tagged-idea` is the factory, bound to
// this project's exclusion the same way `content/lib.typ` binds `note`.
#let todo = tagged-idea("todo")

#note("tag-n-plain")[A plain sugar note — `#note` prepends the "note" tag.]
#todo("tag-t-plain")[A plain sugar todo — `#todo` prepends the "todo" tag.]
#todo("tag-t-both", tags: ("phd",))[
  A todo ALSO tagged phd — reads `("todo", "phd")`, todo first because
  `#todo` prepends its own tag ahead of the caller's.
]
#note("tag-n-both", tags: ("phd",))[A note ALSO tagged phd, no todo.]

#context [
  tag-n-plain is tagged: #repr(tags-of("tag-n-plain")) \
  tag-t-both is tagged: #repr(tags-of("tag-t-both"))
]

// `#window(tags: ..)` selects across the WHOLE rookery, not merely this
// page's own notes — the rule `window-tags.typ`'s regression fixture pins
// (`content/sub/deeper/page.typ`) — so a real rookery's other tagged notes
// can join a selection made here too.
#window(tags: ("todo", "phd"), match: "all")
#window(tags: ("todo", "phd"))

// show-tags: true, alongside show-date: true — both a row of tag pills AND
// the date render in the same hat. Under rheo, the minted page for this note
// also renders its tags UNCONDITIONALLY, which no `demo/pure` root can show.
#note(
  "tag-hat",
  tags: ("draft", "phd", "review"),
  show-tags: true,
  show-date: true,
  created: datetime(year: 2025, month: 2, day: 1),
)[A note with tag pills AND a date in the same hat.]

// The pill row renders in a window's summary too, not just #idea's own card.
#window("tag-hat", show-tags: true)

// A VALUED tag in each of the three shapes a real rookery reaches for: a
// date, a URL, and an opaque id. All three become `idea-tag-*` classes on
// the card and the heading; only the flat `draft` (value `none`) renders a
// pill.
#idea(
  "tag-valued",
  title: [A note with valued tags],
  tags: (
    draft: none,
    "date-deadline": datetime(year: 2026, month: 11, day: 1),
    source: "https://example.org/paper",
    ticket: "PROJ-142",
  ),
  show-tags: true,
)[Carries a date, a URL and an id as tag values; only `draft` shows as a pill.]

#context [
  its tags: #repr(tags-of("tag-valued")) \
  its deadline: #repr(tag-value("tag-valued", "date-deadline")) \
  its source: #repr(tag-value("tag-valued", "source")) \
  its ticket: #repr(tag-value("tag-valued", "ticket"))
]

== A declared projection: `#tag-index` and `ideas(index: ..)`

// A datetime is not a scalar, so a zero-padded string is what makes the
// deadline a usable sort key on a row.
#let INDEX = tag-index((
  deadline: (key: "date-deadline", stamp: true),
))

// Only `tag-valued` above carries a `date-deadline`; every other note comes
// back with `deadline: none` rather than a missing key.
#context {
  let rows = ideas(index: INDEX)
    .filter(r => r.deadline != none)
    .sorted(key: r => r.deadline)
  list(..rows.map(r => [#r.label — deadline #raw(repr(r.deadline))]))
}

== A family that narrows another: several tags from one factory

// `#participant` prepends BOTH tags, so every participant answers a `person`
// selection too without any call site restating it. This is what a factory
// taking several positional tags is for; the `#window` below is the assertion
// that matters — it selects on the WIDER tag and has to find the narrower
// family's notes.
#let person = tagged-idea("person")
#let participant = tagged-idea("person", "participant")

#person("tag-p-person")[A plain person.]
#participant("tag-p-participant")[A participant, which is also a person.]
#participant("tag-p-both", tags: ("phd",))[
  A participant ALSO tagged phd — the caller's tags survive alongside both of
  the factory's own.
]

#context [
  tag-p-person is tagged: #repr(tags-of("tag-p-person")) \
  tag-p-participant is tagged: #repr(tags-of("tag-p-participant")) \
  tag-p-both is tagged: #repr(tags-of("tag-p-both"))
]

#window(tags: "person")

// COMPOSING THE OTHER WAY, and the one shape to avoid. `person.with(tags:
// ("recommender",))` does prepend both — a plain `#recommender[..]` reads
// `("person", "recommender")`, asserted below — but a `.with()`-bound `tags:` is
// a DEFAULT, and a call naming its own `tags:` replaces it outright rather than
// merging. MEASURED: `#recommender("x", tags: ("phd",))` reads
// `("person", "phd")`, having silently dropped the very tag the wrapper exists
// to add. Same failure as the `idea.with(tags: ..)` trap in the factory's own
// banner, one level out. A narrowing that must survive a call site's tags is a
// factory naming both: `tagged-idea("person", "recommender")`.
#let recommender = person.with(tags: ("recommender",))

#recommender("tag-p-with")[
  A recommender built by `.with` — both tags, as long as no call site names its
  own `tags:`.
]

#context [
  tag-p-with is tagged: #repr(tags-of("tag-p-with"))
]
