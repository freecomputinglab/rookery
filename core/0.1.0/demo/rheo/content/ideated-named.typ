#import "lib.typ": demo
#import "@rookery/core:0.1.0": ideate, slug

#show: demo

= Ideated with function name

// A weeknotes-shaped vertebra: every `==` mints its own note, titled and
// named by a custom function that computes the id from the heading and its
// labels. Encoding `labels.len()` in the id makes the array argument
// observable from a minted PATH, proving the function receives it correctly.
#show: ideate.with(
  separator: heading.where(level: 2),
  title: heading,
  name: (content, labels) => "wk-" + str(labels.len()) + "-" + slug(content),
)

== Waterline <tag:waterline>

A section minted with id `wk-1-waterline` — the lambda sees the label as a
one-element array and includes it in the count. The heading is titled as
`Waterline` because `title: heading` is independent of `name:`.

== Rheo

A section minted with id `wk-0-rheo` — the lambda sees no labels as an empty
array, proving both branches work. The heading is titled as `Rheo`.
