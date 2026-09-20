#import "lib.typ": demo, idea

#show: demo

= Numbering a duplicate title-derived id

// Two notes on this one vertebra whose titles both slug to `same-title`.
// `core/0.1.0/src/idea.typ` mints `idea:same-title` for the first and
// `idea:same-title-2` for the second rather than panicking on the duplicate
// id, counted in document order — see the slug-occurrence counter
// (`_slug-peek`/`_slug-record`, `src/state.typ`). `check.sh` asserts both
// pages exist under those exact ids and that each renders its own body.
//
// The first note is ALSO transcluded into a `#window` on `sub/page.typ` — a
// different vertebra — which re-lays-out this same note's mint block a
// second time. `check.sh` asserts that replay leaves `idea:same-title` and
// `idea:same-title-2` exactly as they are here and mints no third page: a
// `same-title-3` would mean the transcluded copy was counted as a new
// occupant of the slug instead of being recognised as this same note.
#idea(title: [Same Title])[
  SAMETITLEONEBODY, the first note titled "Same Title" — mints the bare
  slug `idea:same-title`.
]

#idea(title: [Same Title])[
  SAMETITLETWOBODY, the second note titled "Same Title" — its slug
  collides with the first's, so it mints `idea:same-title-2` instead of
  failing the build.
]
