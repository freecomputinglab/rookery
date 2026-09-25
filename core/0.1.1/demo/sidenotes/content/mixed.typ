#import "@rookery/core:0.1.1": footnote, idea
#import "lib.typ": demo
#show: demo.with(citations: "vertical")

= Mixed: horizontal footnotes, vertical citations

#idea("mixed-note", title: [Mixed note])[
  A paragraph with a footnote#footnote[Still a margin note — `footnotes:`
  stays horizontal on this page.] and a citation to @knuth1984, which stays
  in a normal References block below since this page sets `citations:
  "vertical"`.
]
