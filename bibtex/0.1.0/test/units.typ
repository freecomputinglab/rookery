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
