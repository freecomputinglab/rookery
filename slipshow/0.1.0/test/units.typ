// Unit fixture for @rookery/slipshow's pure helpers. No runner: an `assert`
// that fails fails the compile with a line number, and a passing compile is
// the green light.

#import "/src/lib.typ": *

// Every slip carries the base key, and nothing else by default.
#assert.eq(slip-tags(), (slip: none))

// FLAT keys encode their value in the key, so `slip-fullscreen` and
// `slip-enter-center` are both filterable and both render a pill.
#let with-both = slip-tags(fullscreen: true, enter: "center")
#assert.eq(with-both.at("slip"), none)
#assert.eq(with-both.at("slip-fullscreen"), none)
#assert.eq(with-both.at("slip-enter-center"), none)

// VALUED keys carry the value untouched — this file has no business
// interpreting a colour, gradient, or image.
#assert.eq(slip-tags(background: red).at("slip-background"), red)

// The caller's own `tags:` win outright on a collision.
#assert.eq(slip-tags(tags: (slip: "mine")).at("slip"), "mine")

// `enter-of` decodes from the key rather than storing the name a second time.
#assert.eq(enter-of(slip-tags(enter: "focus")), "focus")
#assert.eq(enter-of((:)), none)
