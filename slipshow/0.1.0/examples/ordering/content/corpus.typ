// The shared corpus every other page in this example queries. Twelve notes,
// each with a PINNED name — never an auto id, which steps a package-wide
// counter that shifts the moment a note is inserted earlier in the file, and
// would silently repoint `index.typ`'s explicit `order:` array.
//
// This is the only page that authors `#slip` notes at all, so a bare
// `tags: "slip"` on any other page resolves to exactly these twelve and
// nothing else — no `demo-*` scoping tag needed the way `demo/rheo/content/
// index.typ` needs one, because nothing outside this file ever carries the
// `slip` tag.
//
// The corpus is deliberately awkward, because the four order forms compared
// across this example are judged on exactly the notes below:
//
//   - `golf` and `kilo` carry no `created:` — undated notes sort LAST under
//     `order: "created"`, never first.
//   - `alpha` and `charlie` share one `created:` date — `order: "created"`
//     breaks the tie by `id`, so `alpha` (the earlier id) leads `charlie`.
//   - `bravo` and `juliett` carry no `slip-order` tag — they sort last, in
//     id order, under the default `order: "slip-order"`.
//   - `echo`, `hotel`, and `india` carry a `weight` tag with a numeric
//     value, for `content/tag-values.typ`'s ordering by tag VALUE.
//   - `kilo`'s title starts with a numeral and `lima`'s starts with a
//     lower-case letter, so `content/functions.typ`'s `order: r => r.label`
//     is visibly a plain string sort (digit, then upper-case, then
//     lower-case) rather than anything alphabetically clever.
//
// Every note's name, title, `created:`, `slip-order`, and any `weight` are
// chosen so the id order, the `r => r.label` order, the `"created"` order,
// and the default `"slip-order"` order all disagree — see this example's
// `content/index.typ` and `content/functions.typ` for the four decks that
// prove it.
#import "lib.typ": template
#import "@rookery/slipshow:0.1.0": slip
#show: template

= The corpus

Twelve notes, authored once here. Every other page in this example queries
them by tag and orders them a different way — nothing below is rendered
specially; it is an ordinary rookery, exactly like any other.

#slip(
  "alpha", title: [Zoo maintenance log],
  created: datetime(year: 2024, month: 3, day: 1), order: 7,
)[
  The rookery keeper counts eggs every morning before opening the aviary gates for visitors.
]

#slip(
  "bravo", title: [Yellow submarine notes],
  created: datetime(year: 2024, month: 1, day: 1),
)[
  A submarine hums beneath the waves while the crew hums along in return.
]

#slip(
  "charlie", title: [Xylophone practice log],
  created: datetime(year: 2024, month: 3, day: 1), order: 2,
)[
  The xylophone rang out eight clear notes across the empty rehearsal hall.
]

#slip(
  "delta", title: [Waffle recipe notes],
  created: datetime(year: 2024, month: 5, day: 1), order: 9,
)[
  Waffles cool on the rack while syrup warms on the stove.
]

#slip(
  "echo", title: [Valley echo report],
  created: datetime(year: 2024, month: 3, day: 15), order: 4,
  tags: (weight: 3),
)[
  The canyon answered every shout with a fainter echo of itself.
]

#slip(
  "foxtrot", title: [Underfoot dance steps],
  created: datetime(year: 2024, month: 1, day: 10), order: 1,
)[
  The dance step turns twice before gliding forward across the floor.
]

#slip(
  "golf", title: [Tundra survey notes], order: 6,
)[
  The tundra stretched flat and pale beneath a thin winter sun.
]

#slip(
  "hotel", title: [Sundial repair log],
  created: datetime(year: 2024, month: 4, day: 1), order: 10,
  tags: (weight: 1),
)[
  The sundial cast a long shadow just past noon on the lawn.
]

#slip(
  "india", title: [Rooftop garden notes],
  created: datetime(year: 2024, month: 1, day: 20), order: 5,
  tags: (weight: 5),
)[
  Tomatoes and basil crowd the narrow beds above a busy street corner.
]

#slip(
  "juliett", title: [Quilt pattern diary],
  created: datetime(year: 2024, month: 2, day: 10),
)[
  The quilt pattern repeats in blue diamonds stitched by hand.
]

#slip(
  "kilo", title: [3 Steps to Espresso], order: 3,
)[
  Three hot shots of espresso, ground fine, pulled fast.
]

#slip(
  "lima", title: [arctic fox sighting log],
  created: datetime(year: 2024, month: 1, day: 5), order: 8,
)[
  A fox crossed the frozen field just after dawn broke.
]
