// `#gutter` — a block of arbitrary content placed at the TOP of the right
// gutter, pushing whatever margin notes and citations follow it further
// down. It relies on one thing core.css already guarantees for a margin
// note: neither the gutter block's own `<div>` nor its `<figure>` host is a
// block formatting context, so a `float: right; clear: right` block placed
// earlier in the DOM is cleared by the next one rather than overlapped by
// it. A gutter block is just another float in that same clearing chain.

#import "base.typ": *
#import "state.typ": *

#let gutter(body, sticky: false) = context {
  assert(
    type(sticky) == bool,
    message: "@rookery/core: `gutter`'s `sticky` must be true or false — got "
      + repr(sticky),
  )
  // Inside a window (`_in-window.get()`, state.typ) there is no right gutter
  // reserved for it — a transcluded body renders vertically throughout, with
  // margin notes falling back to `_footnoted`'s Footnotes block — so a
  // `#gutter` written in a note windowed elsewhere renders as an ordinary
  // block in the flow rather than a floated one.
  if _target() == "html" and _in-window.get() == 0 {
    html.elem(
      "div",
      attrs: (class: _c("gutter"), data-rookery: "gutter")
        + (if sticky { (data-rookery-sticky: "sticky") } else { (:) }),
      body,
    )
  } else {
    block(body)
  }
}
