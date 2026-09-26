// A KNOWN-FAILING fixture: `rheo compile .` here does not succeed. See
// `docs/spikes/note-style-bibliography.md`.
#import "@rookery/core:0.1.1": footnote, idea, rookery
#show: rookery.with(
  footnotes: "horizontal",
  bibliography: arguments(bytes(read("refs.bib")), style: "chicago-notes"),
)

#idea("citing-note", title: [Citing note])[
  A paragraph citing @smith2020, and a plain
  footnote#footnote[An ordinary footnote, alongside the citation's own.].
]
