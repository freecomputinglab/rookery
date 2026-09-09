---
id: rk-test-a-bib-field-longer-than-10k-chars-2defd19b
short-id: '2'
title: Test a bib field longer than 10k chars
priority: 3
labels:
- test-large-bib
deps:
- blocked-by:rk-parse-each-bib-entry-from-its-own-chunk-0e4227b5
closed: false
---
Nothing in `test/` parses a bibliography bigger than a few entries or a field
longer than a line, so the package's two worst failures were both invisible
to `just test`: on a real 832 kB Better BibTeX export the parser took 88
seconds, and on one carrying a 16,576-character `abstract` it did not finish
at all, raising `error: loop seems to be infinite`.

That second one is a hard ceiling, not a slow path: Typst caps a single
`while` loop at exactly 10,000 iterations (measured on typst 0.15.1 — a loop
of 10,000 compiles, one of 10,001 raises that error). Any parser that steps
through a value one character at a time therefore breaks on any field longer
than 10,000 characters. A fixture that carries one would have caught it the
day it was written.

## Decisions already made — do not re-derive

**Generate the fixture in Typst, do not commit a big `.bib`.** `"lorem " *
2000` builds a 12,000-character value in one expression; a committed fixture
file that large is noise in every diff and every checkout.

**Assert on the parse, not on a clock.** A wall-clock assertion is flaky on a
loaded machine and cannot be expressed in a Typst fixture anyway. The
observable this bird locks down is that a long field and a many-entry file
parse CORRECTLY and that the compile terminates; the speed is covered by the
size of the generated corpus — a per-character parser would not finish it
inside any reasonable patience, and a chunked one does it in well under a
second.

## Depends on the chunked parser

This bird BLOCKS ON the bird that rewrites
`/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/parse.typ` so that no loop in
it runs once per character. Before that lands, the fixture below fails by
design with `loop seems to be infinite`. If you see that error, the blocking
bird has not landed — stop and say so; do not weaken the fixture to make it
pass.

## Steps

1. Create `/home/lox/code/_fcl/rookery/bibtex/0.1.0/test/large.typ`. Follow
   `test/units.typ`'s shape exactly: a header comment saying how it is run,
   `#import "/src/lib.typ": *`, and bare `assert.eq` calls — there is no
   runner, a failing assert fails the compile with a line number.

   ```typst
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
   #let MANY = range(400)
     .map(i => "@article{k" + str(i) + ",\n  title = {Paper " + str(i) + "},\n"
       + "  abstract = {" + ("filler " * 200) + "},\n}\n")
     .join("\n")
   #let parsed = parse-bib(MANY)
   #assert.eq(parsed.len(), 400)
   #assert.eq(parsed.at("k399").title, "Paper 399")
   #assert.eq(parsed.keys().filter(k => "abstract" in parsed.at(k)).len(), 400)
   ```

   `"lorem " * 2000` is 12,000 characters and `_squash` trims the trailing
   space, hence `11999`. If your parser's squashing differs on that edge,
   fix the assertion to the true value rather than the parser — the
   interesting assertion is the first two, that a 12,000-character field
   round-trips at all.

2. `/home/lox/code/_fcl/rookery/bibtex/0.1.0/Justfile`, the `test:` recipe:
   add the new fixture immediately after the existing `units.typ` line and
   its `@echo "units OK"`, in the same style:

   ```make
   typst compile --features html --root . --format pdf test/large.typ /dev/null
   @echo "large OK"
   ```

   `--format pdf` with a `/dev/null` output for the same reason `units.typ`
   uses it: typst cannot infer a format from that path and nothing here is
   rendered, only asserted. Extend the recipe's existing comment (Justfile
   lines 3-27) with one sentence naming what `large.typ` covers.

## Do NOT

- Do NOT edit `src/parse.typ`, `src/lib.typ`, or any other source file. This
  bird adds a test and one Justfile line; if the fixture fails, that is the
  blocking bird's business, not this one's.
- Do NOT edit `test/units.typ` — a sibling bird adds assertions there, and
  two flights editing that file conflict when they land.
- Do NOT add a timing assertion, a benchmark harness, or a committed `.bib`
  corpus.
- Do NOT touch `test/check.sh` or the rendered `sweep*` fixtures.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/bibtex/0.1.0 && just test` is green and
   its output includes the `large OK` line between `units OK` and the sweep
   output.

2. The fixture actually bites. Temporarily change `2000` to `20` in
   `test/large.typ` (making the field 120 characters) and confirm the
   `abstract.len()` assertion fails with a line number — then restore
   `2000`. This proves the assertion is reading the field it claims to.