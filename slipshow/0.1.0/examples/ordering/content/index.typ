// The three order forms that need no key function at all, one deck each, on
// one page — see `content/corpus.typ` for the shared corpus every deck below
// queries, and `content/functions.typ` for the fourth form, a key function.
//
// THREE DECKS ON ONE PAGE IS DELIBERATE. Nothing in `#slipshow` enforces one
// deck per page — `src/slipshow.typ`'s own header says the controller uses
// the first `div.slipshow` it finds and ignores the rest. This page is a
// comparison to READ, not one to navigate: only the first deck below
// responds to the arrow keys. That is not a bug in the other two, it is
// what three decks on one page always does.
#import "lib.typ": template
#import "@rookery/slipshow:0.1.0": slipshow
#show: template

= Three ways to order a deck with no key function

== An explicit array of names

Rows named in the array come first, in exactly that sequence; rows the array
does not name are appended afterwards, in id order. Only three of the
corpus's twelve names appear below, so the appended tail is visible rather
than theoretical.

#slipshow(tags: "slip", order: ("lima", "alpha", "kilo"))

== Ascending by `created`

Rows sort by their `created:` date, oldest first. `golf` and `kilo` carry no
`created:` at all, so both land LAST, in id order, rather than first or
anywhere in the middle. `alpha` and `charlie` share one date, so the tie
breaks by id: `alpha` leads `charlie`.

#slipshow(tags: "slip", order: "created")

== The default: ascending by `slip-order`

`#slipshow`'s own default when no `order:` is given at all. `bravo` and
`juliett` carry no `slip-order` tag, so both land LAST, in id order, exactly
as an undated note does under `order: "created"` above.

#slipshow(tags: "slip")
