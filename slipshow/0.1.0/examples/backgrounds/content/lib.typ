// Shared `@rookery/core` configuration for this example. See
// `examples/_template/content/lib.typ` for why this file exists and why it
// is excluded from the spine.
#import "@rookery/core:0.1.0": rookery

#let template(doc) = {
  show: rookery
  doc
}
