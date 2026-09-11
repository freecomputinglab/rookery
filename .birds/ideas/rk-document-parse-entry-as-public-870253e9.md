---
id: rk-document-parse-entry-as-public-870253e9
short-id: '870'
title: Document parse-entry as public
priority: 2
labels:
- chore-bibtex-review
deps:
- blocked-by:rk-hoist-tag-data-out-of-the-all-sweep-767de9e4
closed: false
---
Add `parse-entry` to the two places that list this package's re-exported
public functions — it is already public and already undocumented there.

Touches: /home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ, /home/lox/code/_fcl/rookery/bibtex/0.1.0/readme.md

## The problem, located exactly

`/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/parse.typ` line 60 defines:

```typst
#let parse-entry(chunk) = {
```

with no leading underscore — the naming convention this file uses elsewhere
for anything module-PRIVATE is an underscore prefix (`_value`, `_squash`,
`_BRACES`, `_HEAD`, `_FIELD`, all in this same file). `parse-entry` lacks
that prefix, and `/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ` line
31 does `#import "parse.typ": *` — a wildcard import that brings every
unprefixed name in `parse.typ` into `lib.typ`'s scope, and from there into
`@rookery/bibtex`'s own public surface (anything reachable from
`#import "@rookery/bibtex:0.1.0": *` is, in effect, this package's API).
`parse-entry` is therefore ALREADY public today, not merely public-shaped.

But it is missing from both places that tell a reader what this package
exports:

- `/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ`, the header comment
  at lines 21-23:

  ```typst
  // `parse-bib`, `bib-chunks`, `bib-title`, `cite-key`, `fields-block` and
  // `keyword-tags` are re-exported so a consumer can reach the parts directly
  // rather than only through the factory.
  ```

- `/home/lox/code/_fcl/rookery/bibtex/0.1.0/readme.md` line 107:

  ```markdown
  `parse-bib`, `bib-chunks`, `bib-title`, `cite-key`, `fields-block` and
  `keyword-tags` are re-exported from the entrypoint too, for a consumer that
  wants the parts directly rather than only through the factory.
  ```

Both lists name the same six functions and omit `parse-entry` — a seventh
name that is exactly as reachable as the other six.

This is not a guess about intent: the bird that introduced `parse-entry`
(`rk-parse-each-bib-entry-from-its-own-chunk-0e4227b5` — `bd show` it for the
full text) says explicitly, in its own words, "`bib-chunks` and
`parse-entry` are new PUBLIC names," and then instructs updating the two
lists above to add `bib-chunks` — but never says to add `parse-entry`
alongside it. The omission is that bird's own instructions being followed
literally, not a deliberate decision anywhere to keep `parse-entry` private.
`parse-entry` already has a doc comment of its own (parse.typ lines 53-59)
explaining what it takes and returns, so this bird is purely about the two
places a reader looks to learn the package's overall surface, not about
writing new documentation from scratch.

## Decisions already made — do not re-derive

**Document it as public; do not make it private.** Renaming it to
`_parse-entry` would be the alternative fix, but `parse-entry` parses ONE
already-isolated `@type{key, ..}` chunk into `(key, fields)` — a genuinely
useful primitive for a consumer who has their own way of splitting a `.bib`
file into chunks (a streaming reader, a different delimiter convention) and
wants this package's field-parsing without its chunking. That is a
reasonable thing to expose, and the bird that created it already decided to
expose it. Adding it to the two lists is the smaller, lower-risk fix and
matches that original decision; do not second-guess it here.

## Steps

1. `/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ` lines 21-23,
   change:

   ```typst
   // `parse-bib`, `bib-chunks`, `bib-title`, `cite-key`, `fields-block` and
   // `keyword-tags` are re-exported so a consumer can reach the parts directly
   // rather than only through the factory.
   ```

   to:

   ```typst
   // `parse-bib`, `bib-chunks`, `parse-entry`, `bib-title`, `cite-key`,
   // `fields-block` and `keyword-tags` are re-exported so a consumer can reach
   // the parts directly rather than only through the factory.
   ```

2. `/home/lox/code/_fcl/rookery/bibtex/0.1.0/readme.md` line 107, change:

   ```markdown
   `parse-bib`, `bib-chunks`, `bib-title`, `cite-key`, `fields-block` and
   `keyword-tags` are re-exported from the entrypoint too, for a consumer that
   wants the parts directly rather than only through the factory.
   ```

   to:

   ```markdown
   `parse-bib`, `bib-chunks`, `parse-entry`, `bib-title`, `cite-key`,
   `fields-block` and `keyword-tags` are re-exported from the entrypoint too,
   for a consumer that wants the parts directly rather than only through the
   factory.
   ```

## Do NOT

- Do NOT rename `parse-entry`, change its signature, or move it.
- Do NOT write a new doc comment for `parse-entry` in `parse.typ` — its
  existing one (lines 53-59) already documents behaviour; this bird only
  fixes the two places that list the package's public names.
- Do NOT add `parse-entry` to `test/units.typ` or write a new test for it —
  that is a separate concern (test coverage), not documentation.
- Do NOT touch any other paragraph of `readme.md` or any other file.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/bibtex/0.1.0 && just test` must be green
   — this bird touches only comments and prose, so nothing here should be
   able to change test output, and the run is a pure sanity check.

2. Both lists now name seven functions, not six:

   ```bash
   grep -n "parse-entry" /home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ /home/lox/code/_fcl/rookery/bibtex/0.1.0/readme.md
   ```

   Must print one match in each file, both inside the "re-exported" sentence
   (not inside an unrelated comment).