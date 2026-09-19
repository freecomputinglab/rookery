// Shared imports and template for this example. `#show: rookery` is per-FILE,
// so every page imports this module and applies the show rule once. Excluded
// from the spine (see `rheo.toml`) because it holds no page content of its
// own.
//
// This is the ONE place all three packages this example depends on are named
// — `@rookery/slipshow` itself depends on none of them but core, and the
// import of `@rookery/search` below belongs to this PROJECT's content, not to
// the slipshow package. All three coordinates are written out in full: a
// Typst import spec has to be a literal, and the root `just check-versions`
// checks each one against its manifest.
#import "@rookery/core:0.1.0": rookery
#import "@rookery/search:0.1.0": search-ideas, parse-tag-query, eval-tag-query
#import "@rookery/slipshow:0.1.0": slip, slipshow

#let template(doc) = {
  show: rookery
  doc
}
