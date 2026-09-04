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

// `_ORDER` filtered to the fields `entry` carries, with anything `show-fields`
// names `false` removed. A key `show-fields` does not mention stays — the
// dictionary is a list of exceptions, not a whitelist — and `true` is the same
// as absent, so a project can flip a field back on without deleting the line.
#let _visible-order(entry, show-fields) = {
  let order = _ORDER.filter(k => k in entry) + entry.keys().filter(k => k not in _ORDER).sorted()
  order.filter(k => show-fields.at(k, default: true))
}

// Every field an entry carries, as a labelled HTML definition list — none skipped,
// so a BibTeX field this module has never heard of still surfaces rather than being
// silently dropped. `show-fields` hides some of them: a dictionary mapping a field
// name to `false` removes it from the list. `"entry-type"` is a valid key here too,
// though it names no real BibTeX field — it is the parser's own synthesized key
// behind the `Type` row, hideable the same as any other.
//
// THE LABEL IS PART OF THE BLOCK, so one call gets a page the whole footer and the
// stylesheet can size the label against the rows beneath it. A `<div>` rather than a
// heading: the block sits under a note's own prose and must claim no place in the
// page's outline above it. `label: none` omits it, for a page that heads the block
// itself.
//
// A `show-fields` that hides every field the entry carries returns nothing at
// all — not the label, not an empty `<dl>` — the same reasoning `@rookery/core`
// applies to an empty references block: a heading over an empty table is worse
// than no block.
#let fields-block(entry, label: "Citation", show-fields: (:)) = {
  assert(
    type(show-fields) == dictionary,
    message: "@rookery/bibtex: `show-fields` must be a dictionary, got " + repr(show-fields),
  )
  for (k, v) in show-fields {
    assert(
      type(v) == bool,
      message: "@rookery/bibtex: `show-fields` value for \"" + k + "\" must be a boolean, got "
        + repr(v),
    )
  }
  let order = _visible-order(entry, show-fields)
  if order.len() == 0 { return }
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
