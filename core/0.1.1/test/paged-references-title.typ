// Paged regression fixture for `references-title:` on `#idea` and
// `#idea-body`. Checked by `just test`'s `pdftotext` step, which fails if
// either custom title is missing from the compiled PDF.

#import "/src/lib.typ": idea, idea-body, rookery

#show: rookery.with(
  bibliography: arguments(
    bytes(
      "@book{brooks1975, author = {Brooks, Frederick P.}, title = {The Mythical Man-Month}, publisher = {Addison-Wesley}, year = {1975}}",
    ),
    style: "chicago-author-date",
  ),
)

#idea(<refs-titled>, references-title: [Works Cited])[
  A note citing @brooks1975.
]

#idea-body(<refs-titled>, references-title: [Bibliography])
