---
id: rk-hoist-keywords-typ-s-regexes-to-module-b2e03b85
short-id: b2
title: Hoist keywords.typ's regexes to module scope
priority: 4
labels:
- chore-bibtex-review
deps: []
closed: false
---
Bind `keywords.typ`'s three regexes once at module scope instead of building
them fresh inside a function called once per keyword.

Touches: /home/lox/code/_fcl/rookery/bibtex/0.1.0/src/keywords.typ

## The problem, located exactly

`/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/keywords.typ`, the whole file
(27 lines):

```typst
#let _slugify(s) = {
  let s = lower(s.trim())
  let s = s.replace(regex("[^a-z0-9]+"), "-")
  s.replace(regex("^-+|-+$"), "")
}

#let keyword-tags(raw) = {
  if raw == none { return () }
  raw.split(regex("[,;]")).map(_slugify).filter(s => s != "")
}
```

`_slugify` builds TWO `regex(..)` objects every time it runs, and it runs
once per KEYWORD, via `.map(_slugify)` in `keyword-tags` — so an entry whose
`keywords` field carries ten comma-separated terms compiles twenty regexes to
slugify it. `keyword-tags` itself builds a third regex (the `,`/`;` splitter)
once per call, i.e. once per bibliography ENTRY that has a `keywords` field.

This is the exact anti-pattern this review is checking for, and the one
already found and fixed in `@rookery/search`'s tokenizer: "`regex(..)` built
inside a loop rather than bound once at module scope." `_slugify`'s two
regexes are the more expensive instance here, since they run once per
keyword rather than once per entry.

`/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/parse.typ` already shows the
fix this package uses elsewhere: `_BRACES`, `_HEAD` and `_FIELD` (lines
11-13) are each bound once as a module-level `#let`, and every function that
needs one of them references the bound name rather than calling `regex(..)`
itself.

## Decisions already made — do not re-derive

**Follow `parse.typ`'s own naming convention exactly**: all-caps,
underscore-prefixed, one `#let` per pattern, placed near the top of the
file, above the functions that use them. Do not invent a different naming
scheme for this file.

**Hoist all three regex literals in this file**, not only the two inside
`_slugify` — `keyword-tags`'s own `regex("[,;]")` is the same anti-pattern,
just a cheaper instance of it (once per entry, not once per keyword), and
leaving it in place while fixing the other two would leave the file with two
different conventions for the same thing.

## Steps

All edits are in `/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/keywords.typ`.

1. After the file's header comment (lines 1-6) and before `_slugify`'s own
   doc comment (which currently starts the block at line 8), add three
   module-level bindings:

   ```typst
   #let _NON-ALNUM = regex("[^a-z0-9]+")
   #let _EDGE-HYPHENS = regex("^-+|-+$")
   #let _KEYWORD-SEP = regex("[,;]")
   ```

2. In `_slugify` (current lines 14-18), replace the two inline `regex(..)`
   calls with the bound names:

   ```typst
   #let _slugify(s) = {
     let s = lower(s.trim())
     let s = s.replace(_NON-ALNUM, "-")
     s.replace(_EDGE-HYPHENS, "")
   }
   ```

3. In `keyword-tags` (current lines 24-27), replace the inline
   `regex("[,;]")` with the bound name:

   ```typst
   #let keyword-tags(raw) = {
     if raw == none { return () }
     raw.split(_KEYWORD-SEP).map(_slugify).filter(s => s != "")
   }
   ```

## Do NOT

- Do NOT change the patterns themselves (`[^a-z0-9]+`, `^-+|-+$`, `[,;]`) —
  this bird is purely "build once, reuse", not a behaviour change.
- Do NOT touch `_slugify`'s or `keyword-tags`'s doc comments — they describe
  behaviour, which is unchanged.
- Do NOT touch `parse.typ`, `lib.typ`, `format.typ`, `view.typ` or
  `claim.typ`.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/bibtex/0.1.0 && just test` must be green.
   `test/units.typ` carries `keyword-tags`'s own assertions unchanged
   (currently lines 137-149 — search that file for
   `---- keyword-tags` to find the section if the line numbers have
   shifted):

   ```
   #assert.eq(keyword-tags("ethics, ontology, badiou"), ("ethics", "ontology", "badiou"))
   #assert.eq(keyword-tags("ethics; ontology; badiou"), ("ethics", "ontology", "badiou"))
   #assert.eq(keyword-tags("Digital Humanities"), ("digital-humanities",))
   #assert.eq(keyword-tags("ETHICS, Ontology"), ("ethics", "ontology"))
   #assert.eq(keyword-tags("ethics, !!!, badiou"), ("ethics", "badiou"))
   #assert.eq(keyword-tags(none), ())
   ```

   All six must still pass unchanged — they are the proof that hoisting the
   regexes changed nothing observable.

2. `test/sweep-existing.typ` (part of `just test`'s HTML fixtures) also
   exercises `keyword-tags` through `keywords: "existing"` mode; its stderr
   and the `existing:`/`all:` lines `test/check.sh` prints must be identical
   to the baseline recorded before this bird:

   ```
   existing: aaa=citation+liminal | bbb=citation | ccc=citation | seed=liminal
   all:      aaa=brandnew+citation+liminal | bbb=brandnew+citation | ccc=citation+digital-humanities | seed=liminal
   ```