#import "@rookery/core:0.1.1": footnote, idea
#import "lib.typ": demo
#show: demo.with(citations: auto)

= Mixed: horizontal footnotes, vertical citations

#idea("mixed-note", title: [Mixed note])[
  A paragraph with a footnote#footnote[Still a margin note — `footnotes:`
  stays horizontal on this page.] and a citation to @knuth1984, which stays
  in a normal References block below since this page leaves `citations:` at
  its default.

  A second paragraph whose footnote#footnote[Citing @lamport1994 inside a
  footnote, so its full reference rides at the end of this margin note even
  though citations on this page are vertical.] carries a citation of its own.
]

#idea("native-note", title: [Native footnote])[
  A paragraph using Typst's own footnote#std.footnote[Written with
  std.footnote, still claimed by this idea.] inside an idea.
]
