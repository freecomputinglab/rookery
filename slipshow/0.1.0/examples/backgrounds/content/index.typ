// Colour and gradient backgrounds: the two non-image forms `background:`
// accepts, and the edge cases in each. `bg-index` scopes this page's own
// deck away from the other three pages' slips — a bare `tags: "slip"` on
// `#slipshow` would pull in every slip on every page of this project, the
// same gotcha `demo/rheo/content/index.typ` documents on its own query.
#import "lib.typ": template
#import "@rookery/slipshow:0.1.0": slip, slipshow
#show: template

= Colours and gradients

Six slips below, one per background form and edge case. Every one of them is
correct-looking HTML when wrong — a browser silently ignores a declaration it
cannot parse — so this page exists to be looked at, not just built.

#slip("solid-red", title: [A plain colour], background: red, tags: ("bg-index",))[
  A `color` becomes an inline style, converted through the colour's own
  `.to-hex()` — no alpha channel here, so the hex is six digits.
]

#slip(
  "solid-red-alpha",
  title: [A colour with alpha],
  background: rgb(255, 0, 0, 128),
  tags: ("bg-index",),
)[
  `rgb(255, 0, 0, 128)` carries an alpha channel. Its `.to-hex()` returns the
  eight-digit form, which is valid CSS on its own and needs no special
  handling anywhere in this package, so the page shows through this slip at
  half strength.
]

#slip(
  "linear-default",
  title: [Linear gradient, default angle],
  background: gradient.linear(red, blue),
  tags: ("bg-index",),
)[
  No angle given at all. Typst draws this gradient with red on the left, and
  the correction between Typst's angle scale and CSS's own is what keeps red
  on the left once this becomes a browser declaration instead of a Typst one.
]

#slip(
  "linear-angled",
  title: [Linear gradient, three stops],
  background: gradient.linear(red, yellow, blue, angle: 45deg),
  tags: ("bg-index",),
)[
  Three colour stops and a rotated angle, to exercise the join over more than
  two stops at once rather than only the default case above.
]

#slip(
  "radial",
  title: [Radial gradient],
  background: gradient.radial(red, blue),
  tags: ("bg-index",),
)[
  A radial gradient has no `angle()` of its own — calling one on it is a hard
  Typst error — so this slip is what proves the conversion never reaches for
  it on this branch.
]

// The correction on this branch runs the opposite direction from the linear
// one above: Typst's conic sweep starts due left at `angle: 0deg`, CSS's own
// bare `conic-gradient` starts due up, and the two scales are otherwise
// aligned. Skipping it would still compile and still render, just a quarter
// turn short of the sweep Typst actually drew.
#slip(
  "conic",
  title: [Conic gradient],
  background: gradient.conic(red, blue),
  tags: ("bg-index",),
)[
  A conic sweep from red to blue, anchored at the slip's own centre — read it
  by eye as a cone of colour rather than a declaration a browser dropped.
]

#slipshow(tags: ("slip", "bg-index"), match: "all")
