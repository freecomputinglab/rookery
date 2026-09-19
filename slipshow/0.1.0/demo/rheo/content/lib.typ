// Shared @rookery/core configuration, applied by every page below. `#show:
// rookery` is per-FILE — an import cannot install it for another file — so a
// project applying one configuration wraps it once here and every vertebra
// applies the wrapper. Excluded from the spine (see rheo.toml) because it
// holds no page content of its own.
#import "@rookery/core:0.1.0": rookery

#let demo(doc) = {
  show: rookery
  doc
}
