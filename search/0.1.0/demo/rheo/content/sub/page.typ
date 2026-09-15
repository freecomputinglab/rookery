#import "../lib.typ": demo
#import "@rookery/core:0.1.0": idea, window
#import "@rookery/search:0.1.0": search-bar
#show: demo

= A nested vertebra

This page's handle is `sub:page`, one level deep, so every href rookery computes
from here — to a minted note page, to another vertebra — costs one `../`. A
root-only spine cannot catch an off-by-one in that arithmetic; this page is why
the demo has a subdirectory at all.

// A SECOND BAR, here for the depth arithmetic rather than to show a bar twice.
// Under `mode: "asset"` a page carries no rows of its own: it points at the one
// shared `rookery/search/index.json` and publishes its own `../` prefix, which
// `src/island.js` joins onto every row's site-root href. Both halves are
// per-page, and both fail the same silent way — a search whose every result
// 404s — so `check.sh` asserts them from HERE as well as from the root, which
// is the comparison a root-only fixture cannot make.
#search-bar(placeholder: "Search from one level down")

A page-level citation, outside any note: @lamport1994. And a page-level link
back to #link(label("index"))[the root vertebra].

#idea("sub-note", title: [Sub note], updated: datetime(year: 2026, month: 3, day: 14))[
  A note written on the nested vertebra, windowing back at the root one's note —
  so transclusion is exercised in BOTH directions and the pair is mutually
  windowed. At `window-depth: 0` the inner window becomes a link row,
  which is what keeps the cycle finite.

  #window(<root-note>)
]
