#import "lib.typ": demo, idea, note
#import "@rookery/core:0.1.1": ideas, ideas-outline, tag-index, idea-tag-value, idea-tag-names, window

#show: demo

= Tag surfaces

// `#todo` is not a package export — it's an `idea.with(tag: ..)` constructor
// bound here, off the project's own exclusion-bound `idea`, the same way
// `content/lib.typ` binds `note`.
#let todo = idea.with(tag: "todo")

#note("tag-n-plain")[A plain sugar note — `#note` prepends the "note" tag.]
#todo("tag-t-plain")[A plain sugar todo — `#todo` prepends the "todo" tag.]
#todo("tag-t-both", tags: ("phd",))[
  A todo ALSO tagged phd — reads `("todo", "phd")`, todo first because
  `#todo` prepends its own tag ahead of the caller's.
]
#note("tag-n-both", tags: ("phd",))[A note ALSO tagged phd, no todo.]

#context [
  tag-n-plain is tagged: #repr(idea-tag-names("tag-n-plain")) \
  tag-t-both is tagged: #repr(idea-tag-names("tag-t-both"))
]

// A tag window written INSIDE a note's body, not at page top level — this is
// what gives tag-t-both a NOTE-level backlink rather than only a page-level
// one. Carries neither `todo` nor `phd` itself (`#note` prepends only `note`),
// so it cannot match its own selection.
#note("tag-windower")[
  A note whose body windows by tag rather than by name.

  #window(tagged: ("todo", "phd"), match: "all")
]

// `#window(tagged: ..)` selects across the WHOLE rookery, not merely this
// page's own notes — the rule `window-tags.typ`'s regression fixture pins
// (`content/sub/deeper/page.typ`) — so a real rookery's other tagged notes
// can join a selection made here too.
#window(tagged: ("todo", "phd"), match: "all")
#window(tagged: ("todo", "phd"))

// `display-filter` — a text box and one toggle pill per tag, above the
// figures this call would have emitted. Hidden until `@rookery/search`'s
// script marks the container ready; here there is no such script, so the
// controls stay invisible and this exercises only the markup and its CSS.
#window(
  tagged: ("todo", "phd"),
  unfurl: 0,
  display-filter: true,
  display-filter-tags: ("todo", "phd"),
)

// display-tags: true, alongside display-date: true — both a row of tag pills AND
// the date render in the same hat. Under rheo, the minted page for this note
// also renders its tags UNCONDITIONALLY, which no `demo/pure` root can show.
#note(
  "tag-hat",
  tags: ("draft", "phd", "review"),
  display-tags: true,
  display-date: true,
  created: datetime(year: 2025, month: 2, day: 1),
)[A note with tag pills AND a date in the same hat.]

// The pill row renders in a window's summary too, not just #idea's own card.
#window("tag-hat", display-tags: true)

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
  display-tags: true,
)[Carries a date, a URL and an id as tag values; only `draft` shows as a pill.]

#context [
  its tags: #repr(idea-tag-names("tag-valued")) \
  its deadline: #repr(idea-tag-value("tag-valued", "date-deadline")) \
  its source: #repr(idea-tag-value("tag-valued", "source")) \
  its ticket: #repr(idea-tag-value("tag-valued", "ticket"))
]

// A tagged note with `display-tags: true` NESTED inside another idea. The outer
// note's minted page rebuilds this card from its beacon, which is the only
// path on which the pill can go missing.
#idea("tag-nest-outer", title: [A note containing a tagged note])[
  #idea(
    "tag-nest-inner",
    title: [The nested tagged note],
    tags: ("draft",),
    display-tags: true,
  )[Its pill must survive being replayed on the outer note's minted page.]
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

== A family that narrows another: several tags from one constructor

// `#participant` prepends BOTH tags, so every participant answers a `person`
// selection too without any call site restating it. This is what `base-tags:`
// taking several tags at once is for; the `#window` below is the assertion
// that matters — it selects on the WIDER tag and has to find the narrower
// family's notes.
#let person = idea.with(tag: "person")
#let participant = idea.with(base-tags: ("person", "participant"))

#person("tag-p-person")[A plain person.]
#participant("tag-p-participant")[A participant, which is also a person.]
#participant("tag-p-both", tags: ("phd",))[
  A participant ALSO tagged phd — the caller's tags survive alongside both of
  the constructor's own.
]

#context [
  tag-p-person is tagged: #repr(idea-tag-names("tag-p-person")) \
  tag-p-participant is tagged: #repr(idea-tag-names("tag-p-participant")) \
  tag-p-both is tagged: #repr(idea-tag-names("tag-p-both"))
]

#window(tagged: "person")

// COMPOSING THE OTHER WAY, and the one shape to avoid. `person.with(tags:
// ("recommender",))` does prepend both — a plain `#recommender[..]` reads
// `("person", "recommender")`, asserted below — but a `.with()`-bound `tags:` is
// a DEFAULT, and a call naming its own `tags:` replaces it outright rather than
// merging. MEASURED: `#recommender("x", tags: ("phd",))` reads
// `("person", "phd")`, having silently dropped the very tag the wrapper exists
// to add. Same failure as the `idea.with(tags: ..)` trap `#idea`'s own
// comment warns about, one level out. A narrowing that must survive a call
// site's tags names both in `base-tags:` instead:
// `idea.with(base-tags: ("person", "recommender"))`.
#let recommender = person.with(tags: ("recommender",))

#recommender("tag-p-with")[
  A recommender built by `.with` — both tags, as long as no call site names its
  own `tags:`.
]

#context [
  tag-p-with is tagged: #repr(idea-tag-names("tag-p-with"))
]
