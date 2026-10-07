// The `where:` path: a predicate over the WHOLE registry row, for a
// narrowing `tags:` cannot express — here, `created`. Composed with a plain
// tag query (`tags: "slip"`, every note in this corpus) and `order:
// "created"`, ascending.
//
// `calib-gamma` and `method-theta` carry no `created:` at all
// (`content/corpus.typ`); `where:` drops them, not just sorts them last — an
// undated note is not a weak match for "created 2026 or later", it is a note
// this predicate cannot evaluate as true. Every other pre-2026 note is
// excluded on the same line for the ordinary reason: its date fails the
// test.
#import "lib.typ": template, slipshow
#show: template

= Composed by a row query, ordered by date

Every note in the corpus (`tags: "slip"`), narrowed by `where:` to those
`created` in 2026 or later, ascending. `where:` sees the whole registry row,
not just a note's tags, which is what makes a query over `created` possible
at all — `tags:`'s predicate never sees that field. `calib-gamma` and
`method-theta` carry no `created:` date and are excluded outright, alongside
every dated-but-earlier note.

#slipshow(
  tags: "slip",
  where: r => r.created != none and r.created.year() >= 2026,
  order: "created",
)
