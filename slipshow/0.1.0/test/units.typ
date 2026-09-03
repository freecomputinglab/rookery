// Unit fixture for @rookery/slipshow's pure helpers. No runner: an `assert`
// that fails fails the compile with a line number, and a passing compile is
// the green light.

#import "/src/lib.typ": *
#import "@rookery/core:0.1.0": idea, ideas

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

// Reading a registered note's tags back needs the registry, hence the
// `#context` below; `ideas(values: true)` is what hands back a `tags-dict`
// per row.
#slip("intro", fullscreen: true)[Body]
#slip[Body]
#slip("x", tags: ("draft",))[Body]
#idea("plain")[Body]

#context {
  let rows = ideas(values: true)
  let by-name = name => rows.find(r => r.name == name)

  // A named slip carries both the base key and its own presentation option.
  let intro = by-name("intro")
  assert("slip" in intro.tags-dict)
  assert("slip-fullscreen" in intro.tags-dict)

  // Three slips registered, one of them named by nothing but its auto id —
  // the positional sink is forwarded.
  assert.eq(rows.filter(r => "slip" in r.tags-dict).len(), 3)

  // THE REGRESSION THE `.with()` TRAP WOULD CAUSE: a caller's own `tags:`
  // must MERGE with the `slip` tag, not replace it. If `slip` were missing
  // here, `#slip` was built on `idea.with(tags: (slip: none))` instead of
  // `tagged-idea`.
  let x = by-name("x")
  assert("slip" in x.tags-dict)
  assert("draft" in x.tags-dict)

  // A plain `#idea` stays plain — no `slip-*` key leaks onto an unrelated note.
  let plain = by-name("plain")
  assert(plain.tags-dict.keys().filter(k => k.starts-with("slip")).len() == 0)
}
