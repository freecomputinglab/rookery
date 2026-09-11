// The RENDERED half of the `keywords: "existing"` fixture. `seed` is a
// hand-written note carrying the tag `liminal`, written before the sweep
// runs; `aaa`'s keywords are `liminal, brandnew` (the existing tag plus an
// unused one) and `bbb`'s is `brandnew` alone. `ccc`'s keywords, `Digital
// Humanities`, slugify to `digital-humanities` — a tag nothing else in this
// rookery carries, so it too is dropped, but it is here to prove the
// slug — not the raw, space-carrying keyword — is what gets tested against
// the known-tag set.
//
// `units.typ` covers `keyword-tags` and the slug itself; this covers what
// `"existing"` mode actually keeps once mixed with a real registry read.
#import "@rookery/core:0.1.0": rookery, idea, ideas
#import "/src/lib.typ": bibtex

#let BIB = "@book{aaa,\n  title = {A},\n  keywords = {liminal, brandnew},\n}\n\n@book{bbb,\n  title = {B},\n  keywords = {brandnew},\n}\n\n@book{ccc,\n  title = {C},\n  keywords = {Digital Humanities},\n}\n"
#let refs = bibtex(BIB, keywords: "existing")

#show: rookery

#idea("seed", tags: "liminal")[A hand-written note.]
// `aaa` claimed by hand — exercising `citation`'s own context-wrapped path
// for `"existing"` mode, not only `all()`'s, which already runs inside one.
#(refs.citation)("aaa")[]
#(refs.all)()

// One `<div class="kw-row">` per registered note, id and sorted tag list in
// their own spans — `check.sh` greps these to confirm which keywords
// survived the existing-tag filter.
#context {
  for i in ideas() {
    html.elem("div", attrs: (class: "kw-row"), {
      html.elem("span", attrs: (class: "kw-id"), i.id)
      html.elem("span", attrs: (class: "kw-tags"), i.tags.sorted().join(","))
    })
  }
}
