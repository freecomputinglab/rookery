// THE RANKED DECK — the page this example exists for. `search-ideas` scores
// every note against a text query and returns registry rows in RANK order;
// handing those rows' `name`s to `slips:` is the only way to turn a ranking
// into a deck at all, because a ranking is an ORDER and `slips:` is the one
// `#slipshow` parameter that accepts one directly.
//
// `search-ideas` calls `@rookery/core`'s `ideas()` WITHOUT `values: true`, so
// its rows carry `tags` as a flat array and no `tags-dict` — one more reason
// the NAME is what crosses to `slips:` rather than anything from the row
// itself: slipshow re-reads each note's presentation options off the
// registry by name, not off whatever shape a ranking call happens to return.
//
// Passing `window(r.name)` instead of `r.name` compiles and renders, but
// silently drops every `#slip` option (fullscreen, background, enter, ...):
// `#window` wraps its whole body in a `context { .. }` block
// (`core/0.1.0/src/window.typ` line 148), and a Typst context block's content
// is opaque until evaluated, so the marker walk that reads those options
// finds nothing inside it. `select.typ`'s own header records the same
// warning. Passing the bare name instead defers rendering to `#slipshow`
// itself, by which point the options are read off the registry row directly.
//
// `order:` is refused alongside `slips:` (`resolve-slips` in `select.typ`) —
// the ranking IS the order, so it is never passed here.
#import "lib.typ": template, search-ideas, slipshow
#show: template

= Composed and ordered by search rank

Eight notes, ranked by `search-ideas("calibration")` rather than sorted by id
or date — a title that opens with "calibration" outranks one that merely
mentions it partway through, so the deck below is not the corpus's usual id
order. One of the eight, the top hit, carries `fullscreen: true`: proof that a
presentation option survives the trip from a ranking back into a deck.

#context {
  let hits = search-ideas("calibration", limit: 8)
  // `hits.map(r => r.name)`, never `hits.map(r => window(r.name))` — see the
  // header above for why the latter silently drops every `#slip` option.
  slipshow(slips: hits.map(r => r.name))
}
