// The fixture for `citations: "notes"` (template.typ): a note-class CSL
// (`chicago-notes`) turns `auto` into that mode, so every prose citation
// below renders as one of this package's own footnotes rather than a native
// Typst one — `check.sh` asserts on the resulting markup.
#import "@rookery/core:0.1.1": footnote, hyperlink, idea, rookery
#show ref: hyperlink

#show: rookery.with(
  footnotes: "horizontal",
  bibliography: arguments(bytes(read("refs.bib")), style: "chicago-notes"),
)

#idea("citing-note", title: [Citing note])[
  A paragraph citing @smith2020, and a plain
  footnote#footnote[An ordinary footnote, alongside the citation's own.].
]

#idea("supplement-note", title: [Supplement note])[
  A paragraph citing @smith2020[p.~9], a page-specific supplement carried
  through to the promoted footnote's own reference.
]

#idea("footnote-cite-note", title: [Footnote cite note])[
  A paragraph with a footnote whose own body cites something#footnote[This
  footnote cites @smith2020 inside its own body.].
]

#idea("linking-note", title: [Linking note])[
  A link back to @idea:citing-note, which must stay an ordinary note link —
  not a promoted citation footnote — since its target is not a bibliography
  key.
]
