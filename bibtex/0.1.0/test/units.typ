// Unit fixture for @rookery/bibtex. Run with `just test` from
// `bibtex/0.1.0`. There is no runner and no JS: an `assert` that fails
// fails the compile with a line number, and a passing compile is the green
// light — the same shape `@rookery/core` and `@rookery/timeline` use.

#import "/src/lib.typ": *

// ---- parse-bib — a two-entry fixture yields both keys ----------------------
#let TWO = "@book{badiou2002,\n  title = {Ethics},\n}\n\n@article{smith2020,\n  title = {A Paper},\n}\n"
#assert.eq(parse-bib(TWO).keys().sorted(), ("badiou2002", "smith2020"))

// The entry type is recorded under its own key, which a real BibTeX field name
// can never carry — a field name cannot contain a hyphen — so it can't collide
// with a field the entry actually has.
#assert.eq(parse-bib(TWO).at("badiou2002").entry-type, "book")

// Interior braces are dropped entirely, not just the outer pair: in BibTeX an
// interior brace protects capitalization from the citation style rather than
// saying anything about the text.
#assert.eq(parse-bib("@misc{k, title = {{An} Essay},}").at("k").title, "An Essay")

// A value split across source lines squashes to single spaces — the
// indentation belongs to the file, not to the title.
#assert.eq(
  parse-bib("@misc{k, title = {A\n    Multi-Line\n    Title},}").at("k").title,
  "A Multi-Line Title",
)

// A quoted value and a bare value both parse.
#assert.eq(parse-bib("@misc{k, note = \"quoted\",}").at("k").note, "quoted")
#assert.eq(parse-bib("@misc{k, year = 2002,}").at("k").year, "2002")

// ---- cite-key — a string, a label, or a ref, all read back the key --------
#assert.eq(cite-key("badiou2002"), "badiou2002")
#assert.eq(cite-key(<badiou2002>), "badiou2002")
#assert.eq(cite-key(ref(<badiou2002>)), "badiou2002")

// ---- bib-title — the note title an entry derives ---------------------------
//
// `bib-title` returns CONTENT, not a string, so comparing it needs the exact
// same markup shape it builds rather than a hand-assembled equivalent —
// Typst's content equality is structural, and `[Badiou, ]` + `emph(..)` does
// not equal one sequence built as `[#by, ]#emph(..)`. `_expect` mirrors
// `bib-title`'s own construction so the comparison is meaningful rather than
// weakened to a type check.
#let _expect(by, work, year) = [#if by != none [#by, ]#emph(work)#if year != none [ (#year)]]

// `shorttitle` wins over `title` when both are present.
#assert.eq(
  bib-title((shorttitle: "Ethics", title: "Ethics: An Essay", author: "Alain Badiou", year: "2002")),
  _expect("Badiou", "Ethics", "2002"),
)

// Three or more authors cut to the first surname plus `et al.`.
#assert.eq(
  bib-title((title: "A Paper", author: "Jane Smith and John Doe and Alex Lee")),
  _expect("Smith et al.", "A Paper", none),
)

// Neither `author` nor `editor`: the title stands with no byline at all.
#assert.eq(bib-title((title: "No Byline Here")), _expect(none, "No Byline Here", none))

// No title at all: `none`, rookery's own "this note has no authored title".
#assert.eq(bib-title((author: "Someone")), none)

// ---- bibtex(..) — the factory's own shape -----------------------------------
//
// `all` is a field on the returned dictionary, and a function — the sweep a
// project calls once. What it MINTS is document-level behaviour and needs the
// rendered fixture in `test/sweep.typ`; this only checks the shape.
#assert.eq(type(bibtex(TWO).all), function)

// `all()` mints in `bib.keys().sorted()` order, alphabetical rather than
// insertion order — a fixture whose keys are already alphabetical (like
// `TWO` above) cannot tell the two apart, hence a fixture entered in reverse.
#let UNSORTED = "@book{zeta, title = {Z},}\n\n@book{alpha, title = {A},}\n"
#assert.eq(bibtex(UNSORTED).bib.keys().sorted(), ("alpha", "zeta"))

// A bad `keywords:` value is rejected, naming the three accepted ones —
// exercised by reading `bibtex(..)`'s own assert message rather than by a
// negative test case: Typst has no way to catch a panic, so a fixture cannot
// assert one without aborting the whole compile.

// ---- _visible-order — fields-block's show-fields filter --------------------
//
// `fields-block` returns content, so the filter that decides which fields
// appear is tested directly rather than through rendered markup — `check.sh`
// covers the markup itself, on a fixture that actually renders.
#let _ENTRY = (entry-type: "book", title: "Ethics", author: "Alain Badiou", doi: "10.1/x")

// Omitted entirely: every field shows, in `_ORDER`'s sequence.
#assert.eq(_visible-order(_ENTRY, (:)), ("entry-type", "author", "title", "doi"))

// A partial dictionary hides only what it names `false`; a field it doesn't
// mention stays.
#assert.eq(_visible-order(_ENTRY, ("doi": false)), ("entry-type", "author", "title"))

// `true` is the same as absent: shown.
#assert.eq(
  _visible-order(_ENTRY, ("doi": true)),
  ("entry-type", "author", "title", "doi"),
)

// An unknown key changes nothing — `show-fields` is validated on its values,
// not its keys, so a misspelt one silently hides nothing.
#assert.eq(
  _visible-order(_ENTRY, ("isbn": false)),
  ("entry-type", "author", "title", "doi"),
)

// Hiding every field the entry carries yields an empty order — `fields-block`
// returns early on this rather than emitting a label over nothing.
#assert.eq(
  _visible-order(_ENTRY, ("entry-type": false, "title": false, "author": false, "doi": false)),
  (),
)

// ---- keyword-tags — a BibTeX `keywords` field as rookery tag slugs --------
//
// Better BibTeX emits either separator depending on export settings, so both
// are accepted; each part is trimmed, lowercased, and every run of
// non-alphanumeric characters collapses to one hyphen with the ends
// stripped.
#assert.eq(keyword-tags("ethics, ontology, badiou"), ("ethics", "ontology", "badiou"))
#assert.eq(keyword-tags("ethics; ontology; badiou"), ("ethics", "ontology", "badiou"))

// A keyword with a space would otherwise break its CSS class — slugifying
// collapses it to one hyphen. Mixed case folds too.
#assert.eq(keyword-tags("Digital Humanities"), ("digital-humanities",))
#assert.eq(keyword-tags("ETHICS, Ontology"), ("ethics", "ontology"))

// Punctuation-only keyword slugifies to the empty string and is dropped.
#assert.eq(keyword-tags("ethics, !!!, badiou"), ("ethics", "badiou"))

// No `keywords` field at all: an empty array, not an error.
#assert.eq(keyword-tags(none), ())
