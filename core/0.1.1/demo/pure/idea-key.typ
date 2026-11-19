// Fixture for `idea-key`, which needs `#context` to read the configured
// prefix — `test/units.typ` cannot cover it, since that harness compiles
// with no `#show: rookery` and no context. Covers the three input forms
// `_norm` treats as equivalent under the DEFAULT prefix; `root-prefix.typ`
// carries the non-default case, since the prefix is document-wide state and
// cannot vary within one compile.
//
// Build (PDF):  typst compile --features html --root ../.. idea-key.typ build/idea-key.pdf
// Build (HTML): typst compile --features html --format html --root ../.. idea-key.typ build/idea-key.html

#import "../../src/lib.typ": idea-key, rookery
#show: rookery

#context {
  assert.eq(idea-key("etal"), "idea:etal")
  assert.eq(idea-key(<etal>), "idea:etal")
  assert.eq(idea-key("idea:etal"), "idea:etal")
}
