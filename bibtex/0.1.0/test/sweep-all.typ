// The RENDERED half of the `keywords: "all"` fixture — the same entries as
// `sweep-existing.typ`, so the two fixtures are directly comparable, but
// every keyword becomes a tag whether or not the rookery already has it.
// `aaa` picks up both `liminal` and `brandnew`, `bbb` picks up `brandnew`,
// and `ccc`'s `Digital Humanities` becomes the single tag
// `digital-humanities` — proving the slug, not the raw space-carrying
// keyword, is what lands in the class list (see `check.sh`'s scan for a
// stray class token).
#import "@rookery/core:0.1.0": rookery, idea, ideas
#import "/src/lib.typ": bibtex

#let BIB = "@book{aaa,\n  title = {A},\n  keywords = {liminal, brandnew},\n}\n\n@book{bbb,\n  title = {B},\n  keywords = {brandnew},\n}\n\n@book{ccc,\n  title = {C},\n  keywords = {Digital Humanities},\n}\n"
#let refs = bibtex(BIB, keywords: "all")

#show: rookery

#idea("seed", tags: "liminal")[A hand-written note.]
// `aaa` claimed by hand, exercising `citation`'s plain (non-context) path —
// `"all"` mode needs no registry read, so it never wraps this call.
#(refs.citation)("aaa")[]
#(refs.all)()

#context {
  for i in ideas() {
    html.elem("div", attrs: (class: "kw-row"), {
      html.elem("span", attrs: (class: "kw-id"), i.id)
      html.elem("span", attrs: (class: "kw-tags"), i.tags.sorted().join(","))
    })
  }
}
