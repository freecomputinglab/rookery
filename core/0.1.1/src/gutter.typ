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
  // Always the floated element on html, whether or not this body is being
  // rendered inside a `#window`: core.css resets `[data-rookery="gutter"]`
  // back to `static` positioning inside `[data-rookery="window"]`, so the
  // fallback to an ordinary flowed block lives there, not here.
  if _target() == "html" {
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
