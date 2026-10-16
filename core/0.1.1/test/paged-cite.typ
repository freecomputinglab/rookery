// Paged regression fixture for a prose citation written OUTSIDE any `#idea`
// or `#window`. Checked by `just test`'s `pdftotext` step (no `assert` can see
// rendered text), which fails if the citation or its bibliography entry is
// missing from the compiled PDF.

#import "/src/lib.typ": rookery

#show: rookery.with(
  citations: "notes",
  bibliography: arguments(
    bytes(
      "@book{brooks1975, author = {Brooks, Frederick P.}, title = {The Mythical Man-Month}, publisher = {Addison-Wesley}, year = {1975}}",
    ),
    style: "chicago-notes",
  ),
)

A paragraph citing @brooks1975 in page prose, with no enclosing note.
