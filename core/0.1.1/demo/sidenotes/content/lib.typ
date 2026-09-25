// The one `#show: rookery` configuration both vertebrae in this demo apply —
// `demo/rheo/content/lib.typ` next door is the same pattern, for the same
// reason: `#show: rookery` is per-file, so a project wanting one
// configuration across several vertebrae wraps it once here.
#import "@rookery/core:0.1.1": rookery

// `citations:` is a per-vertebra override, unlike everything else here: the
// mode marker each page carries is emitted from `rookery()`'s PARAMETER, not
// from document-wide state (template.typ), so passing a different value
// through `demo.with(citations: ..)` on one vertebra is what lets that one
// page's marker disagree with the others sharing this wrapper — `mixed.typ`
// is the one page in this project that does.
#let demo(citations: auto, doc) = {
  show: rookery.with(
    footnotes: "horizontal",
    citations: citations,
    bibliography: arguments(bytes(read("refs.bib"))),
    right-gutter: 40%,
    display-right-gutter: true,
    // A distinctive theme so `geom.sh` can tell a themed sidenote border
    // (this colour) apart from core's own default.
    theme: (border-color: rgb("#cc3300"), link-color: rgb("#0055aa")),
  )
  doc
}
