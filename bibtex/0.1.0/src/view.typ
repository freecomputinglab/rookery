// Rendering a parsed BibTeX entry's fields as an HTML definition list.

// The order a reader wants: who, what, where it appeared, then the numbers,
// then the handles. Any field NOT listed here still renders — it is appended
// after these, sorted, so an unusual BibTeX field is shown rather than lost.
#let _ORDER = (
  "entry-type", "author", "editor", "translator", "title", "shorttitle",
  "booktitle", "journal", "series", "publisher", "address", "edition",
  "volume", "number", "pages", "year", "month", "doi", "url", "urldate",
  "isbn", "issn", "keywords", "note", "abstract",
)

// Field names whose capitalized form reads badly.
#let _TERMS = (
  "entry-type": "Type",
  "shorttitle": "Short title",
  "booktitle": "Book title",
  "urldate": "Accessed",
  "doi": "DOI",
  "url": "URL",
  "isbn": "ISBN",
  "issn": "ISSN",
)

// Every field an entry carries, as a labelled HTML definition list — none skipped,
// so a BibTeX field this module has never heard of still surfaces rather than being
// silently dropped.
//
// THE LABEL IS PART OF THE BLOCK, so one call gets a page the whole footer and the
// stylesheet can size the label against the rows beneath it. A `<div>` rather than a
// heading: the block sits under a note's own prose and must claim no place in the
// page's outline above it. `label: none` omits it, for a page that heads the block
// itself.
#let fields-block(entry, label: "Citation") = {
  let order = _ORDER.filter(k => k in entry) + entry.keys().filter(k => k not in _ORDER).sorted()
  let term = k => _TERMS.at(k, default: upper(k.first()) + k.slice(1))
  let value = (k, v) => {
    if k == "doi" {
      link("https://doi.org/" + v, v)
    } else if k == "url" {
      link(v, v)
    } else {
      v
    }
  }
  if label != none {
    html.elem("div", attrs: (class: "citation-fields-head"), label)
  }
  html.elem("dl", attrs: (class: "citation-fields"), {
    for k in order {
      html.elem("dt", term(k))
      html.elem("dd", value(k, entry.at(k)))
    }
  })
}
