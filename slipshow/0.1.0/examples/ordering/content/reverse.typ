// `reverse:`, on the two orders where descending is what an author actually
// wants. It composes with either the built-in `"created"` form
// (`content/index.typ`) or a key function (`content/functions.typ`) — not
// with `slips:`, an explicit array, which `resolve-slips` refuses alongside
// `reverse:` because an explicit array is already in the order it was
// written.
//
// `reverse:` reverses the KEYED rows only (`src/select.typ`'s `_sort-pairs`).
// An undated note is not "first" in a reverse-chronological deck — it is
// still the note with no date, and it is still LAST. A reader who has not
// seen this will assume the opposite; the deck below is what proves it.
#import "lib.typ": template
#import "@rookery/slipshow:0.1.0": slipshow
#show: template

= Descending orders

== Reverse-chronological

The single most-wanted presentation order: newest first. `golf` and `kilo`
carry no `created:`, so they are still LAST here, exactly where they sit in
`content/index.typ`'s ascending `"created"` deck — `reverse:` never moves an
unkeyed row.

#slipshow(tags: "slip", order: "created", reverse: true)

== Reverse-alphabetical by `label`

The exact reverse of `content/functions.typ`'s `order: r => r.label` deck:
every row has a `label` (it is never `none`), so every row is keyed and
`reverse:` flips the whole sequence.

#slipshow(tags: "slip", order: r => r.label, reverse: true)
