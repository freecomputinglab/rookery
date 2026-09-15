// Large-corpus fixture for @rookery/bibtex. Run with `just test` from
// `bibtex/0.1.0`. Same shape as `test/units.typ`: no runner, a failing
// `assert` fails the compile with a line number.

#import "/src/lib.typ": *

// A field longer than Typst's 10,000-iteration `while` ceiling. A parser
// that steps character by character cannot read this at all.
#let LONG = "lorem " * 2000
#let ONE = "@book{k,\n  title = {A Book},\n  abstract = {" + LONG + "},\n}\n"
#assert.eq(parse-bib(ONE).at("k").title, "A Book")
#assert.eq(parse-bib(ONE).at("k").abstract, LONG.trim())
#assert.eq(parse-bib(ONE).at("k").abstract.len(), 11999)

// A corpus, so the cost of the file is exercised rather than the cost of
// one entry: 400 entries, each with an abstract of its own.
//
// The outer parens are load-bearing: a `#let` binding's right-hand side
// stops parsing at the end of its first line, so a method chain that wraps
// across lines (`.map(..)` / `.join(..)` each on their own line) silently
// binds `MANY` to the un-joined array unless the whole expression is inside
// one `(..)` that keeps the parser in code mode across the newlines.
#let MANY = (
  range(400)
    .map(i => "@article{k" + str(i) + ",\n  title = {Paper " + str(i) + "},\n"
      + "  abstract = {" + ("filler " * 200) + "},\n}\n")
    .join("\n")
)
#let parsed = parse-bib(MANY)
#assert.eq(parsed.len(), 400)
#assert.eq(parsed.at("k399").title, "Paper 399")
#assert.eq(parsed.keys().filter(k => "abstract" in parsed.at(k)).len(), 400)
