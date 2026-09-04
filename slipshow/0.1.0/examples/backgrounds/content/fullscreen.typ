// The bookend layout: a fullscreen opening slip, three ordinary slips, and a
// fullscreen closing slip — the shape a reader copies most. `bg-fullscreen`
// scopes this page's own deck; see `index.typ`'s comment on why a bare
// `tags: "slip"` is never safe across a project with more than one deck.
//
// `pattern.png` and `texture.jpg`, one PNG and one JPEG so both `data:` MIME
// types get exercised, are kept to a few kilobytes each on purpose: typst's
// HTML export inlines an image as base64, so its bytes land inside the page
// itself rather than beside it, and a real photograph here would bloat
// every build of this example.
#import "lib.typ": template
#import "@rookery/slipshow:0.1.0": slip, slipshow
#show: template

= Fullscreen bookends

#slip(
  "fs-opening",
  title: [Opening, over an image],
  fullscreen: true,
  background: image("pattern.png"),
  tags: ("bg-fullscreen",),
)[
  This slip is fullscreen and its background is a generated pattern, not a
  colour or a gradient. Typst's own HTML export turns the image into a
  self-contained data URI, so there is no path here for a stylesheet to
  resolve. Read this paragraph against whatever the pattern draws behind it
  and judge whether the text stays legible.
]

#slip("fs-plain", title: [An ordinary slip, no background], tags: ("bg-fullscreen",))[
  Between the two fullscreen bookends sit three ordinary slips. This one
  carries no background at all — the deck's own plain page background shows
  through, exactly as it would for a slide built with a bare idea.
]

#slip(
  "fs-gradient",
  title: [An ordinary slip with a gradient],
  background: gradient.linear(purple, orange, angle: 120deg),
  tags: ("bg-fullscreen",),
)[
  A gradient is not exclusive to fullscreen slips — this is an ordinary,
  non-fullscreen section carrying the same inline gradient declaration a
  fullscreen slip would get.
]

#slip(
  "fs-image",
  title: [An ordinary slip with an image],
  background: image("texture.jpg"),
  tags: ("bg-fullscreen",),
)[
  An image background works the same way here as on a fullscreen slip: its
  layer sits behind this slip's own box, sized to that box rather than to
  the viewport.
]

#slip(
  "fs-closing",
  title: [Closing, over a gradient, longer than the viewport],
  fullscreen: true,
  background: gradient.linear(rgb("#1b1035"), rgb("#5f2a75"), angle: 200deg),
  tags: ("bg-fullscreen",),
)[
  This closing slip is fullscreen over a gradient, and its body is
  deliberately longer than a screen's worth of text — a two-word slip proves
  nothing about overflow, so this one does not stop there.

  A first paragraph, to build up height. A second paragraph, still building.
  A third paragraph, and by now the box should already be taller than a
  typical viewport if the fullscreen rule is doing what it claims. A fourth
  paragraph, to be sure it clears even a tall monitor. A fifth and final
  paragraph, so this is genuinely the end of the deck rather than an
  arbitrary stopping point chosen to make the page short.
]

#slipshow(tags: ("slip", "bg-fullscreen"), match: "all")
