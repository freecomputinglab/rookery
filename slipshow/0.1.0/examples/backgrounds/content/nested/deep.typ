// THE DEPTH ASSERTION: one slip with an image background, authored one
// level below the spine's root. A `url(pattern.png)` background would
// resolve against a different directory here than it would at the root —
// `../pattern.png` at this depth, a bare `pattern.png` there — and only one
// of the two paths is ever correct on a given page. `src/slipshow.typ`
// never emits a `url(..)`, only the self-contained data URI Typst's own
// HTML export already produced, so depth plays no part in whether this
// slip's background shows up.
#import "../lib.typ": template
#import "@rookery/slipshow:0.1.0": slip, slipshow
#show: template

= A slip one level down

#slip(
  "nested-image",
  title: [The same image, from underneath],
  background: image("../pattern.png"),
  tags: ("bg-nested",),
)[
  This is the same file the fullscreen page's opening slip uses, reached
  through a different relative path because this page lives one directory
  below it. The emitted data URI is byte-identical either way, which is the
  whole point of inlining the image rather than pointing at it.
]

#slipshow(tags: ("slip", "bg-nested"), match: "all")
