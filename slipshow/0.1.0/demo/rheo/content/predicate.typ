// `tags:` also accepts a PREDICATE — a function from a tag dictionary to a
// bool (`select.typ`) — as the extension point for a full boolean grammar
// with no dependency on `@rookery/search`. A project wanting the `a&b`
// grammar builds the predicate from that package's `parse-tag-query`/
// `eval-tag-query` and hands the result straight to `tags:`; this file proves
// the extension point works with `@rookery/search` installed nowhere at all —
// the predicate below is a plain inline Typst closure.
#import "lib.typ": demo
#import "@rookery/slipshow:0.1.0": slip, slipshow
#show: demo

= Deck built from a tag predicate

#slip("a", title: [Fullscreen, selected], fullscreen: true, tags: ("demo-predicate",))[
  Fullscreen and tagged for this page, so the predicate below keeps it.
]

#slip("b", title: [Not fullscreen, dropped], tags: ("demo-predicate",))[
  Tagged for this page but not fullscreen, so the predicate below drops it —
  the note still exists in the registry, it simply is not in this deck.
]

#slip("c", title: [Fullscreen, selected], fullscreen: true, tags: ("demo-predicate",))[
  A second fullscreen slip, also kept.
]

// `demo-predicate` scopes the predicate to this page's own three notes: the
// registry is project-wide (see `index.typ`'s own comment on `ideas()`), and
// `a`/`c`'s bare `slip-fullscreen` tag would otherwise also match the
// fullscreen bookends on `deck.typ`.
#let is-selected-fullscreen = t => "demo-predicate" in t and "slip-fullscreen" in t

#slipshow(tags: is-selected-fullscreen)
