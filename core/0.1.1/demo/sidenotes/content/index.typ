#import "@rookery/core:0.1.1": footnote, idea, window
#import "lib.typ": demo
#show: demo

= Rookery with horizontal footnotes

#idea("margin-note", title: [Margin note])[
  A first paragraph with one footnote#footnote[The first margin note, beside
  this paragraph's own line.].

  A second paragraph with two footnotes on the same
  line#footnote[The second margin note.]#footnote[The third margin note,
  which stacks below the second rather than overlapping it.], exercising the
  clear/stacking behaviour.

  A third paragraph with no footnotes at all, but citing @knuth1984 for
  its own margin note.

  A fourth paragraph with a footnote whose body itself cites a
  work#footnote[Citing @lamport1994 here, so its full reference sits inline
  in this sidenote rather than spawning a second margin note.].
]

#idea("host-note", title: [Host note])[
  A note whose body transcludes the note above, so its margin notes are
  replayed a second time under a different block number.
  #window(<margin-note>)
]

#idea("plain-wide", title: [Plain wide])[
  A first paragraph with no footnotes or citations at all, so this card
  keeps its full width.

  A second paragraph, same reason.
]

#idea("forced-gutter", title: [Forced gutter], display-right-gutter: true)[
  A card with no footnotes or citations, but `display-right-gutter: true`
  splits it anyway.
]

#idea("no-gutter", title: [No gutter], display-right-gutter: false)[
  A card with one footnote#footnote[Forced back to the vertical Footnotes
  block by `display-right-gutter: false`, even though the document is in
  horizontal mode.], which falls back to the vertical block instead of a
  margin note.
]
