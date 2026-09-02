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

// Every field an entry carries, as an HTML definition list — none skipped, so a
// BibTeX field this module has never heard of still surfaces rather than being
// silently dropped.
#let fields-block(entry) = {
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
  html.elem("dl", attrs: (class: "citation-fields"), {
    for k in order {
      html.elem("dt", term(k))
      html.elem("dd", value(k, entry.at(k)))
    }
  })
}
