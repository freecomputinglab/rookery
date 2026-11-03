#import "@rookery/core:0.1.1": footnote, gutter, idea
#import "lib.typ": demo
#show: demo

= Gutter blocks

#gutter(sticky: true)[#strong[Contents] #lorem(30)]

#idea("after-panel", title: [After panel])[
  A first paragraph with a footnote#footnote[Displaced below the page-level
  gutter block above, rather than under it.].

  #lorem(300)
]

#idea("own-block", title: [Own block])[
  #gutter[Card aside]

  A paragraph with a footnote#footnote[Displaced below this card's own
  gutter block, rather than under it.].

  #lorem(300)
]

#lorem(600)
