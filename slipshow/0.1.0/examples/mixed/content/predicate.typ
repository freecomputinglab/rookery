// The `where:` route: a predicate over the whole registry row, needing no
// shared tag at all. Selects two notes out of `corpus.typ`'s ten — one
// `#slip`, one plain `#idea` — by a plain string test on their label.
#import "lib.typ": template
#import "@rookery/slipshow:0.1.0": slipshow
#show: template

= A deck built by predicate

`where:` reaches `r.label`, not `r.title`: `label` is a `str`, always, while
`title` is content and `.starts-with()` has no method on it (`ideas()`
documents `label` as the field for exactly this, `@rookery/core`'s
`data.typ` line 327). Reaching for `title` here is the mistake this page
exists to avoid making.

#slipshow(where: r => r.label.starts-with("Method"))
