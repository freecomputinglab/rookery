#import "lib.typ": demo
#import "@rookery/core:0.1.1": ideate, ideate-name

#show: demo

= Ideated by explicit id

// `separator: none` gives a single-note body no heading to derive a `name:`
// from at all — the case `#ideate-name` exists for. One beacon anywhere in
// the body names the note explicitly; `check.sh` looks for a minted page at
// this exact id rather than at a counter value.
#ideate(separator: none)[
  FIXEDIDBODY, a lone paragraph minted under a fixed id from its own
  #ideate-name("fixed-id-note") beacon rather than the package counter.
]

// Asking explicitly for `separator: par` splits this into two notes; only
// the second carries a beacon, proving the mechanism is per-section rather
// than document-wide and that its unbeaconed sibling still mints under the
// counter as before.
#ideate(separator: par)[
  AUTOCOUNTBODY, a paragraph with no beacon, minted under the package's own
  auto-incrementing counter.

  SECONDPARABODY, a paragraph naming itself explicitly.
  #ideate-name("second-para-note")
]
