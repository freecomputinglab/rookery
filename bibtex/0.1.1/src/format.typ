// Deriving a citation note's title from a parsed BibTeX entry, and reading
// back the key a `#citation` call was written with.

// The BibTeX key a `#citation` was written with. `@key` is the form to write —
// Typst parses it as a `ref`, so a key that is not in the bibliography is caught
// by Typst's own checking as well as by the missing-key assert once the
// bibliography is consulted — with a bare label or a string taken too, for a
// call that computes its key.
#let cite-key(r) = {
  if type(r) == str { return r }
  if type(r) == label { return str(r) }
  if type(r) == content and r.func() == ref { return str(r.target) }
  panic("citation: expected `@key`, a label or a string, got " + repr(r))
}

// Surnames, in the order the entry lists them. BibTeX writes an author list as
// `Last, First and Last, First`, but a Zotero export can also emit `First Last`
// where the record has no split name — hence the two branches. The unsplit one
// takes the LAST WORD, so `Ursula Le Guin` reads as `Guin`: a particle is only
// knowable from the comma form, which is what a record with a split name gives.
#let _surnames(names) = {
  if names == none { return () }
  names
    .split(" and ")
    .map(a => {
      let a = a.trim()
      if a.contains(",") { a.split(",").first().trim() } else { a.split(" ").last() }
    })
    .filter(s => s != "")
}

// Two names read as a pair, three or more as the first plus `et al.` — the same cut
// a reader's eye makes, and the note's title is a shelf label rather than a
// reference.
#let _byline(names) = {
  if names.len() == 0 {
    none
  } else if names.len() == 1 {
    names.first()
  } else if names.len() == 2 {
    names.join(" and ")
  } else {
    names.first() + " et al."
  }
}

// What a citation note is CALLED: `Badiou, Ethics (2002)`.
//
// `shorttitle` FIRST, which is why Better BibTeX's own field is worth having: the
// full title of the Badiou is `Ethics: An Essay on the Understanding of Evil`, and
// a rookery row, a browser tab and an `@idea:` link all want the two syllables the
// book is known by. The full title is the fallback, not the other way round.
//
// `editor` stands in for a missing `author` — an edited collection is cited by the
// people who made it — and every part is optional: an entry with nothing but a
// title yields the title, and one with no title at all yields `none`, which is
// rookery's own "this note has no authored title" and leaves it to derive a label
// from the body.
#let bib-title(entry) = {
  let work = entry.at("shorttitle", default: entry.at("title", default: none))
  if work == none { return none }
  let by = _byline(_surnames(entry.at("author", default: entry.at("editor", default: none))))
  let year = entry.at("year", default: none)
  [#if by != none [#by, ]#emph(work)#if year != none [ (#year)]]
}
