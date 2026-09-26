#import "@rookery/core:0.1.1": footnote, idea, window
#import "lib.typ": demo
#show: demo

= Rookery with horizontal footnotes

#idea("margin-note", title: [Margin note], created: datetime(year: 2026, month: 1, day: 15), display-date: true)[
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

  #quote(block: true)[
    A blockquoted paragraph, citing @knuth1984 again and carrying its own
    footnote#footnote[The fifth margin note, inside the blockquote — its
    note still lines up with the card's gutter.].
  ]

  - A list item with a footnote#footnote[The sixth margin note, inside the
    list item — same gutter, same alignment.].
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

#idea("with-bib", title: [With bibliography], display-bibliography: true)[
  A paragraph citing @knuth1984, whose margin note shows as usual, but
  `display-bibliography: true` also keeps this card's own References block
  visible even though citations render horizontally.
]

#idea("no-bib", title: [No bibliography], display-bibliography: false)[
  A paragraph citing @knuth1984, whose References block is hidden by
  `display-bibliography: false` in every mode.
]

#idea("bib-group", title: [Bibliography group])[
  A `#window((<margin-note>, <with-bib>), display-bibliography: false)` sits
  below this paragraph: one combined References block for both notes, listing
  Knuth once even though both cite it, and hidden by the group's own
  `display-bibliography: false` rather than by the citations mode.

  #window((<margin-note>, <with-bib>), display-bibliography: false)
]
