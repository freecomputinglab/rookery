// The one place the demo is configured, applied by both vertebrae — same
// reason `@rookery/core`'s own demo does this (see its `content/lib.typ`):
// `#show: rookery` is per-FILE, so a project that wants one configuration
// wraps it once here and every vertebra applies the wrapper.
#import "@rookery/core:0.1.0": rookery
#import "@rookery/bibtex:0.1.0": bibtex

#let refs = bibtex(read("../references.bib"))

// Appended after every minted page's OWN body — `entry.typ`'s hand-written
// citation as much as every entry `index.typ`'s `all()` sweeps — so a reader
// lands on the bibliographic record regardless of which path minted the
// page. A NAMED TOP-LEVEL FUNCTION, deliberately: `idea-page-template` is
// read back from document-wide state, so an inline closure built inside
// `demo` below would be a different value per vertebra and whichever file
// happened to compile last would win.
// `id` arrives prefixed (`idea:<key>`, the default `prefix:` `#show: rookery`
// publishes) — the bare BibTeX key, which is what `refs.fields` looks up, is
// everything after the first `:`.
#let citation-page(id: none, note: (:), doc) = {
  doc
  if id != none {
    (refs.fields)(id.split(":").last())
  }
}

#let demo(doc) = {
  show: rookery.with(idea-page-template: citation-page)
  doc
}
