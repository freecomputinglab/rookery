#import "@rookery/core:0.1.1": footnote, idea, rookery, window
#show: rookery.with(footnotes: "horizontal", bibliography: arguments(bytes(read("refs.bib"))))

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
