// Ordering by a note's own tag VALUE — what `tags-dict` (the full tag
// dictionary, values included) is for, as opposed to `tags`, the flat array
// of tag NAMES `where:`/`order:` see on every other page in this example.
// Only `echo`, `hotel`, and `india` carry a `weight` tag
// (`content/corpus.typ`); the other nine do not.
//
// `where:` and `order:` composing on the same call is the point of the first
// deck below: `where:` runs first and narrows the corpus to rows that HAVE
// the key, so `order:`'s `.at("weight")` never has to handle a missing one.
#import "lib.typ": template
#import "@rookery/slipshow:0.1.0": slipshow
#show: template

= Ordering by a tag's value

== Filtered to the notes that carry `weight`

#slipshow(
  tags: "slip",
  where: r => "weight" in r.tags-dict,
  order: r => r.tags-dict.at("weight"),
)

== Unfiltered: a missing `weight` sorts last

Drop the `where:` and the same key function still works: a row with no
`weight` looks up a key that is not there, `.at("weight", default: none)`
returns `none`, and `none` sorts LAST — the same rule an undated note follows
under `order: "created"` (`content/index.typ`). The nine keyless notes below
are not filtered out, they are simply after the three that have a `weight`.

#slipshow(tags: "slip", order: r => r.tags-dict.at("weight", default: none))
