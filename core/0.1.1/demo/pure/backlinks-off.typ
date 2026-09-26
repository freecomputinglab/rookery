// Proves `rookery.with(backlinks: false)` stops the backlink graph being
// harvested at all: a note that links another records no outbound links, and
// the page-links beacon that `.marrow.typ` would otherwise invert is never
// emitted.
//
// Build (HTML only — this fixture asserts on the registry, not on output):
//   typst compile --features html --format html --root ../.. backlinks-off.typ build/backlinks-off.html

#import "../../src/lib.typ": idea, idea-key, rookery, window, _registry
#show: rookery.with(backlinks: false)

#idea(<b>)[Target note.]
#idea(<a>)[Links to b: #window("b")]

#context {
  let reg = _registry.final()
  assert.eq(reg.at(idea-key("a")).links, ())
  assert.eq(reg.at(idea-key("a")).tag-links, ())
  assert.eq(query(<rookery-page-links>).len(), 0)
}
