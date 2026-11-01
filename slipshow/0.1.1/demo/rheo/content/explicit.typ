// The EXPLICIT-ARRAY route: `#slipshow(slips: ..)` reads its options back out
// of already-rendered content via `src/marker.typ`'s `slip-meta`, rather than
// querying the registry — the code path `index.typ` does not exercise at
// all. The ideas are written INLINE in the call, so nothing here is ever
// placed a second time: unlike a tag-queried deck, this page shows each slip
// exactly once.
#import "lib.typ": demo
#import "@rookery/slipshow:0.1.1": slip, slip-rows, slipshow
#show: demo

#let eq = $ "short" &-> "a" \ "much longer left side" &-> "b" $

= Deck built from an explicit array

// `reveal: false` is this page's second job: it is the ONE deck in this
// fixture that opts out of the progressive reveal, so `check.sh` has a
// `data-reveal="all"` root to assert against alongside the three that take
// the default. A three-slip deck on a page about how the array route reads
// its options back is also the case where showing everything at once costs a
// reader least.
#slipshow(reveal: false, slips: (
  slip("intro", title: [Written in the order it runs], fullscreen: true)[
    An explicit array is already ordered by construction, so `#slipshow`
    refuses an `order:` argument here rather than silently ignoring it.
  ],
  slip(background: rgb("#e4edf5"))[
    An UNNAMED slip: `resolve-slips` still has to hand it back as a `"content"`
    entry, and `select.typ`'s renderer falls back to its position (`slip-1`)
    for the `id` a named row would otherwise supply.
  ],
  slip("centered", enter: "center")[
    Overrides the deck's default `scroll` entry for this one slip alone.
  ],
  slip("joined", join: true)[Flush against the slip above: no gap between them.],
  slip("lines", lines: true, eq),
  // An OVERLAY: covers every row of the lines slip before it, re-drawing
  // both with the right side "b" in gold, and the camera stays still.
  slip("lines-gold", over: true, { show "b": set text(fill: rgb("#c08000")); slip-rows(eq).join() }),
  // A REPLACEMENT: takes the place of everything before it in the stack,
  // both rows included, in flow, so it can be taller than what it replaces.
  slip("lines-replaced", replace: true)[
    Replaced outright, and taller than the line it replaces.

    Going back brings the line back.
  ],
  slip("prose", lines: true)[
    First paragraph.

    Second paragraph.

    + one
    + two
  ],
))
