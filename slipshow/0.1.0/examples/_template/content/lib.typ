// Shared `@rookery/core` configuration for this example. `#show: rookery` is
// per-FILE — an import cannot install it for another file — so every page
// imports `template` from here and applies it once. Excluded from the spine
// (see `rheo.toml`) because it holds no page content of its own.
#import "@rookery/core:0.1.0": rookery

#let template(doc) = {
  show: rookery
  doc
}
