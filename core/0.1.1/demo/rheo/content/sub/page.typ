#import "../lib.typ": demo, vertebra-link
#import "@rookery/core:0.1.1": idea, window
#show: demo

= A nested vertebra

This page's handle is `sub:page`, one level deep, so every href rookery computes
from here — to a minted note page, to another vertebra — costs one `../`. A
root-only spine cannot catch an off-by-one in that arithmetic; this page is why
the demo has a subdirectory at all.

A page-level citation, outside any note: @lamport1994. And a page-level link
back to #vertebra-link("index")[the root vertebra].

#idea("sub-note", title: [Sub note], created: datetime(year: 2026, month: 3, day: 14))[
  A note written on the nested vertebra, windowing back at the root one's note —
  so transclusion is exercised in BOTH directions and the pair is mutually
  windowed. At `window-unfurl: 0` the inner window becomes a link row,
  which is what keeps the cycle finite.

  #window(<root-note>)
]

A window emitted from INSIDE a `#context` block, which is what any package
computing its own rows must do — `@rookery/todos`'s views are the real
case. The backlink walk reads a page's content at `#show: rookery` time and
cannot enter a context block, so a window written like this must announce
itself for the note it transcludes to gain its backlink from this page.
`check.sh` asserts that `plain-note` lists this vertebra.

#context {
  window("plain-note", folded: true)
}

// Transcludes the FIRST of `same-title-pair.typ`'s two same-titled notes,
// from a different vertebra than the one that authored it — re-laying-out
// its mint block a second time. `check.sh` asserts this replay does not
// grow `idea:same-title`'s slug into a `same-title-3`.
#window("same-title", folded: true)
