---
id: rk-parse-each-bib-entry-from-its-own-chunk-0e4227b5
short-id: '0'
title: Parse each bib entry from its own chunk
priority: 4
labels:
- perf-parse
deps: []
closed: false
---
`parse-bib` walks a `.bib` file one character at a time through a Typst
`while` loop. That is fine for the 2-entry fixtures in `test/units.typ` and
unusable for a real bibliography.

MEASURED, typst 0.15.1, on an 832 kB Better BibTeX export of 1416 entries
(422 of them carrying an `abstract`):

- The whole file **fails to parse at all**: `error: loop seems to be
  infinite`, raised at `src/parse.typ:34` — the brace loop inside
  `_read-value`. One `abstract` value in that export is 16,576 characters
  long, and Typst caps a single `while` loop at exactly 10,000 iterations
  (measured directly: a loop of 10,000 compiles, one of 10,001 raises that
  error). Any field longer than 10,000 characters kills the parse.
- With every `abstract`, `file`, `note` and `keywords` line stripped out
  (434 kB), it does parse — in **88 seconds**.
- A prototype that splits the file into entries first and scans values by
  jumping between delimiters parses the UNTOUCHED 832 kB file, abstracts
  included, in **0.72 seconds**.

So this is both a ~120x speedup and a correctness fix: an ordinary Zotero
library cannot be read by this package today.

## Decisions already made — do not re-derive

**Split into entries first, then parse each entry.** The two costs are
compounding: `src.clusters()` on line 67 builds one array with a element per
character (832k of them), and every `cs.at(i)` then indexes into it. Working
one entry at a time keeps every array small, and it is where nearly all of
the 120x comes from — the prototype's numbers above are with the same
per-character logic still inside each entry for the value scan.

**Split on `"\n@"`, using `str.split`.** It is native Rust, so the whole
832 kB split costs nothing measurable. The known limitation, which is
acceptable: a braced value containing a line that itself begins with `@`
would be cut in the wrong place. BibTeX exports do not wrap values that way
(a wrapped value is indented), and the current parser's own handling of that
case is not worth 88 seconds.

**Scan a value by jumping between braces, not character by character.**
`s.matches(regex("[{}]"))` returns every brace position in one native pass;
depth counting then loops over BRACES (usually two or four) rather than over
characters. This is what removes the 10,000-iteration ceiling — no loop in
the new code runs once per character.

**A verified prototype exists and is reproduced below.** It was run against
the same 434 kB file as the current parser: both return 1416 entries, and
exactly one entry differs — `liHrtDownDocumentProcessor2022`, whose title is
`{{{H}}\ding{164}{{️rtDown}}: {{Document Processor}} for {{Executable Linear
Algebra Papers}}`. The CURRENT parser truncates it, returning that entry with
only two fields and a cut title; the prototype returns all 13 fields and the
full title. The rewrite therefore also fixes a real mis-parse. Treat the
prototype as the intended implementation, not as a sketch.

## Steps

All edits are in `/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/parse.typ`
(126 lines). Nothing else in the package changes.

1. Delete `_WS` (line 6), `_skip-ws` (lines 8-11) and `_read-value`
   (lines 26-61). Keep `_squash` (line 16) exactly as it is.

2. Add the value reader, the entry parser and the chunk splitter below. This
   is the prototype verbatim; keep the names, and write the package's usual
   explanatory comments over each (see "Comment style" in the repo's
   `CLAUDE.md`: describe the present, keep the measurement, drop the lab
   notebook).

   ```typst
   #let _BRACES = regex("[{}]")
   #let _HEAD = regex("^@([A-Za-z]+)\\s*\\{\\s*([^,\\s]+)\\s*,")
   #let _FIELD = regex("^[\\s,]*([A-Za-z][A-Za-z0-9_\\-]*)\\s*=\\s*")

   // One value, from `s` sitting on its first character. Returns `(value, next)`.
   #let _value(s) = {
     if s.starts-with("{") {
       let depth = 0
       let end = none
       for m in s.matches(_BRACES) {
         if m.text == "{" { depth += 1 } else {
           depth -= 1
           if depth == 0 { end = m.start; break }
         }
       }
       if end == none { return (s.slice(1).replace("{", "").replace("}", ""), s.len()) }
       (s.slice(1, end).replace("{", "").replace("}", ""), end + 1)
     } else if s.starts-with("\"") {
       let q = s.slice(1).position("\"")
       if q == none { return (s.slice(1), s.len()) }
       (s.slice(1, q + 1), q + 2)
     } else {
       let e = s.position(regex("[,}]"))
       if e == none { return (s, s.len()) }
       (s.slice(0, e), e)
     }
   }

   // One `@type{key, ..}` chunk -> `(key, fields)`, or `none` if it is not an entry.
   #let parse-entry(chunk) = {
     let m = chunk.match(_HEAD)
     if m == none { return none }
     let fields = ("entry-type": lower(m.captures.at(0)))
     let rest = chunk.slice(m.end)
     while true {
       let fm = rest.match(_FIELD)
       if fm == none { break }
       let after = rest.slice(fm.end)
       let (value, next) = _value(after)
       fields.insert(lower(fm.captures.at(0)), _squash(value))
       rest = after.slice(next)
     }
     (m.captures.at(1).trim(), fields)
   }

   // `key -> that entry's own source text`, split natively.
   #let bib-chunks(src) = {
     let out = (:)
     for chunk in ("\n" + src).split("\n@") {
       let c = chunk.position(",")
       if c == none { continue }
       let head = chunk.slice(0, c)
       let b = head.position("{")
       if b == none { continue }
       out.insert(head.slice(b + 1).trim(), "@" + chunk)
     }
     out
   }
   ```

   Note the leading `"\n" + src`: it makes the file's first entry break on
   the same `\n@` as every other one, so it is not handed to `parse-entry`
   with a doubled `@`.

3. Rewrite `parse-bib` (lines 66-126) to use them, keeping its signature and
   return shape — `key -> (field: value, ..)`, field names lowercased, values
   squashed, the entry type under the `"entry-type"` key:

   ```typst
   #let parse-bib(src) = {
     let out = (:)
     for (key, chunk) in bib-chunks(src) {
       let e = parse-entry(chunk)
       if e != none { out.insert(e.at(0), e.at(1)) }
     }
     out
   }
   ```

4. `bib-chunks` and `parse-entry` are new PUBLIC names — `src/lib.typ`
   line 31 does `#import "parse.typ": *`, so they arrive there for free.
   Update the re-export sentence in two places to name `bib-chunks`
   alongside `parse-bib`: the header comment at `src/lib.typ:21-23`, and
   `readme.md:89`.

## Do NOT

- Do NOT change `src/lib.typ`'s `bibtex(..)` factory, its returned
  dictionary, or when it parses. Making the factory lazy or filtered is a
  separate bird.
- Do NOT change `_squash`, `format.typ`, `view.typ`, `claim.typ` or
  `keywords.typ`.
- Do NOT add an `abstract`-skipping or field-filtering option here.
- Do NOT edit `test/units.typ`. Its existing `parse-bib` assertions (lines
  10, 15, 20, 25, 30, 31) must pass UNCHANGED — that is most of this bird's
  proof.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/bibtex/0.1.0 && just test` is green,
   including the untouched `parse-bib` assertions in `test/units.typ` and
   the rendered `all()` fixtures.

2. Speed and the long-field fix, against a real library. In a scratch
   directory, with `BIB` set to any Better BibTeX export of a few hundred
   entries (`/home/lox/code/waterline/rookery/references.bib` is the 832 kB,
   1416-entry file all the numbers above were measured on):

   ```bash
   cd /tmp && cat > bigparse.typ <<'EOF'
   #import "/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/parse.typ": parse-bib
   #let b = parse-bib(read("/home/lox/code/waterline/rookery/references.bib"))
   entries: #b.len(), abstracts: #b.values().filter(e => "abstract" in e).len()
   EOF
   time typst compile --root / bigparse.typ bigparse.pdf
   ```

   It must COMPILE (before this bird it dies with `loop seems to be
   infinite`), report `entries: 1416, abstracts: 422`, and finish in under
   five seconds — the prototype does it in 0.72s.