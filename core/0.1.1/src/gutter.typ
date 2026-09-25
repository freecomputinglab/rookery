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
