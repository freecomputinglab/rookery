---
id: rk-add-only-to-bibtex-for-a-subset-e4dfea67
short-id: e4
title: 'Add only: to bibtex for a subset'
priority: 3
labels:
- feat-only-filter
deps:
- blocked-by:rk-parse-each-bib-entry-from-its-own-chunk-0e4227b5
closed: false
---
`bibtex(..)` parses every entry in the file it is handed, and `all()` then
mints a note for every one of them. A consumer whose `.bib` is a whole
reference manager library gets a note — and, on a rheo site, a PAGE — per
entry, when it wanted notes for the handful of works it has actually written
about.

A real case, `waterline`: 1416 entries in `references.bib`, four of them
referred to anywhere on the site. That site now filters the `.bib` SOURCE
TEXT by hand before calling `bibtex(..)`, reimplementing an entry splitter in
its own `_lib/template.typ` to do it. The package should offer the parameter
instead.

## Decisions already made — do not re-derive

**`only:` filters, it does not merely hide.** The kept keys are the only ones
parsed, so the cost of a large bibliography scales with what is used rather
than with the file. This is the whole point of the parameter; a filter
applied after parsing would save nothing.

**A key in `only:` that the file does not carry is silently dropped, not an
error.** `entry(key)` already asserts `no `<key>` in the bibliography` at the
moment something actually asks for that entry, which is a better error than
one raised at factory-construction time about a key nobody ended up wanting.
Say so in the readme.

**`only: auto` (the default) means the whole file**, matching today's
behaviour exactly. Do not use `none` for that — `none` reads as "no entries"
and the difference matters when a caller computes the list.

**Do not make the factory lazy.** Parsing on demand per key would mean the
returned `bib` could no longer be a plain dictionary, which every consumer
reads directly, and the sibling bird's chunked parser already brings a
1416-entry library down to well under a second. `only:` is the cheap half of
the win and breaks nothing.

## Depends on the chunked parser

This bird BLOCKS ON the bird that rewrites
`/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/parse.typ` to split a `.bib`
into per-entry chunks. What that bird adds, and what this one uses, is one
new public function in `parse.typ`:

```typst
// `key -> that entry's own source text`
#let bib-chunks(src) = { .. }
```

`src/lib.typ` line 31 already does `#import "parse.typ": *`, so `bib-chunks`
is in scope with no new import. If it is missing when you start, the
blocking bird has not landed and this one cannot be implemented — stop and
say so rather than writing a second splitter here.

## Steps

1. `/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ`, the `bibtex`
   signature at lines 58-64: add `only: auto` as the last named parameter,
   after `show-fields: (:)`.

2. Same file, lines 74-75, currently:

   ```typst
   let src = if type(src) == array { src.join("\n") } else { src }
   let bib = parse-bib(src)
   ```

   Keep the join, then parse either everything or the selected chunks:

   ```typst
   let src = if type(src) == array { src.join("\n") } else { src }
   let bib = if only == auto { parse-bib(src) } else {
     let chunks = bib-chunks(src)
     let kept = only.filter(k => k in chunks).map(k => chunks.at(k))
     if kept.len() == 0 { (:) } else { parse-bib(kept.join("\n")) }
   }
   ```

3. Same file, add an `assert` beside the existing `keywords` one at lines
   65-69, so a wrong shape fails where it is written:

   ```typst
   assert(
     only == auto or type(only) == array,
     message: "@rookery/bibtex: `only` must be auto or an array of keys — got " + repr(only),
   )
   ```

4. Document it in the header comment of the same file (the parameter list at
   lines 4-16 names each of `bib`, `entry`, `fields`, `citation`, `all`) and
   in `readme.md`: the signature line at line 34
   (`bibtex(src, tagged-idea:, tag:, keywords:, show-fields:)`), the
   paragraph under it, and one short paragraph in the `all()` section
   (readme lines 62-80) saying that `all()` sweeps the entries the factory
   knows, so `only:` is how a large library mints a small number of notes.
   Include the reason a missing key is not an error.

5. `test/units.typ`, in the `parse-bib` section that ends at line 31, add
   assertions using the `TWO` fixture already defined at line 9:

   ```typst
   #assert.eq(bibtex(TWO, only: ("smith2020",)).bib.keys(), ("smith2020",))
   #assert.eq(bibtex(TWO, only: ()).bib.len(), 0)
   #assert.eq(bibtex(TWO, only: ("nosuchkey",)).bib.len(), 0)
   #assert.eq(bibtex(TWO).bib.keys().sorted(), ("badiou2002", "smith2020"))
   ```

   `bibtex` is already in scope there — `test/units.typ` line 6 imports
   `/src/lib.typ` with `*`.

## Do NOT

- Do NOT touch `src/parse.typ`. The blocking bird owns that file, and both
  editing it is how the two flights conflict on landing.
- Do NOT add a second way to say the same thing (no `except:`, no `keys:`
  alias, no glob or regex matching in `only:`).
- Do NOT change `all()`'s once-per-document guard in `src/claim.typ`, or the
  `citation`/`entry`/`fields` closures.
- Do NOT change the default behaviour: `bibtex(src)` with no `only:` must
  parse and sweep the whole file exactly as it does now.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/bibtex/0.1.0 && just test` is green,
   including the four new assertions.

2. A subset factory mints only its subset. In a scratch directory:

   ```bash
   cd /tmp && cat > onlysweep.typ <<'EOF'
   #import "/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ": bibtex
   #import "@rookery/core:0.1.0": ideas, rookery
   #show: rookery
   #let refs = bibtex(
     "@book{a, title = {A},}\n@book{b, title = {B},}\n@book{c, title = {C},}\n",
     only: ("a", "c"),
   )
   #(refs.all)()
   #context [minted: #ideas(values: true).map(n => n.name).sorted().join(",")]
   EOF
   typst compile --features html --format html --root / onlysweep.typ onlysweep.html
   grep -o "minted: [a-z,]*" onlysweep.html
   ```

   It must print `minted: a,c`. Dropping the `only:` line and recompiling
   must print `minted: a,b,c`.

   Honest about this one: the `ideas(values: true)` read-back above is
   written from the idiom in this package's own `test/sweep.typ` (which
   mints under `#show: rookery` and greps the rendered HTML) but has not
   been run as written. If the field names differ, mirror `test/sweep.typ`
   lines 10-40 exactly rather than inventing a third shape — the assertion
   that matters is which keys `all()` minted.