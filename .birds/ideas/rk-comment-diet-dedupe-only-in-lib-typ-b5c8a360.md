---
id: rk-comment-diet-dedupe-only-in-lib-typ-b5c8a360
short-id: b5
title: 'Comment diet: dedupe only: in lib.typ'
priority: 3
labels:
- chore-bibtex-review
deps:
- blocked-by:rk-store-claimed-keys-as-a-dictionary-ec9241ef
- blocked-by:rk-hoist-tag-data-out-of-the-all-sweep-767de9e4
- blocked-by:rk-document-parse-entry-as-public-870253e9
closed: false
---
Comment diet: `lib.typ`'s `only:` parameter is explained twice in one file,
and once with a historical aside that has no present-tense meaning.

Touches: /home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ

## The rubric

`/home/lox/code/_fcl/rookery/CLAUDE.md`, the "Comment style" section, is the
standard here. Two of its rules are what this bird acts on:

- **Describe the present.** Never what the code used to be, or what it was
  before some change.
- **The same fact stated twice in one file** earns nothing the second time —
  keep it in the one place a reader would look for it.

## The problem, located exactly

`/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ` explains `only:`'s
"filter before parsing, not after" contract in full TWICE:

Once in the module header, lines 59-65:

```typst
// `only:` parses just the named keys out of `src`, so a large library costs
// what it's USED rather than what it contains. `auto` (the default) parses
// the whole file, exactly as before this parameter existed — not `none`,
// which would read as "parse nothing". A key `only` names that `src` doesn't
// carry is dropped silently; nothing here errors on it, because `entry(key)`
// already asserts on a missing key at the point something asks for it,
// which is a more useful place to fail than factory construction.
```

And again, right at the point of use, lines 88-92:

```typst
  // `only:` filters the SOURCE before parsing, not the parsed result after —
  // the whole point is that a library's cost scales with what's kept rather
  // than with the file. A key `only` names that the file doesn't carry is
  // silently dropped here; `entry(key)` below is where that turns into an
  // error, at the point something actually asks for it.
```

Both say: `only:` filters before parsing so cost scales with what's kept;
`auto` means the whole file; a key the source doesn't carry is silently
dropped; `entry(key)` is where a missing key becomes an error. That is one
fact, told twice, in the same file, to the same reader.

The header copy also carries a historical aside with no present-tense
content: "`auto` (the default) parses the whole file, exactly as before this
parameter existed." There is no "before" in the code as it stands — `only:`
is simply a parameter whose default is `auto`, which means the whole file.
The comparison to a prior version of the function is exactly the pattern the
rubric names: "never what it used to be."

## Decisions already made — do not re-derive

**Keep the full explanation at the header** (lines 59-65) — it is the
module-level doc comment a reader consults first to learn `bibtex(..)`'s
parameters, alongside `keywords:`'s own explanation immediately above it
(lines 45-57). Shrink the inline copy (lines 88-92) to a short pointer back
to it, rather than deleting it outright — a reader looking at the
implementation still deserves a one-line orientation, just not the whole
argument again. This mirrors a pattern already used elsewhere in this same
package: `claim.typ`'s comment on `_swept` explicitly says "see `all()`'s
own comment for why," rather than re-explaining `.get()` vs `.final()` a
second time.

**Drop the historical clause from the header**, not merely reword it — "auto
(the default) parses the whole file" already states the present behaviour
completely; "exactly as before this parameter existed" adds nothing a reader
acting on the code today can use.

## Steps

Both edits are in `/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ`.

1. Lines 59-65, replace:

   ```typst
   // `only:` parses just the named keys out of `src`, so a large library costs
   // what it's USED rather than what it contains. `auto` (the default) parses
   // the whole file, exactly as before this parameter existed — not `none`,
   // which would read as "parse nothing". A key `only` names that `src` doesn't
   // carry is dropped silently; nothing here errors on it, because `entry(key)`
   // already asserts on a missing key at the point something asks for it,
   // which is a more useful place to fail than factory construction.
   ```

   with:

   ```typst
   // `only:` parses just the named keys out of `src`, so a large library costs
   // what it's USED rather than what it contains. `auto` (the default) parses
   // the whole file — not `none`, which would read as "parse nothing". A key
   // `only` names that `src` doesn't carry is dropped silently; nothing here
   // errors on it, because `entry(key)` already asserts on a missing key at the
   // point something asks for it, which is a more useful place to fail than
   // factory construction.
   ```

2. Lines 88-92, replace:

   ```typst
     // `only:` filters the SOURCE before parsing, not the parsed result after —
     // the whole point is that a library's cost scales with what's kept rather
     // than with the file. A key `only` names that the file doesn't carry is
     // silently dropped here; `entry(key)` below is where that turns into an
     // error, at the point something actually asks for it.
   ```

   with:

   ```typst
     // `only:` filters the source before parsing, not the parsed result after
     // — see the header comment above for why, and for the missing-key
     // contract.
   ```

## Do NOT

- Do NOT change any code — this bird is comments only. Confirm your diff
  before landing: every changed line must be inside a `//` comment.
- Do NOT touch the `keywords:` explanation (lines 45-57) or the
  `_show-fields` comment (lines 83-86) — only the two `only:` passages named
  above.
- Do NOT touch `parse.typ`, `claim.typ`, `format.typ`, `view.typ` or
  `keywords.typ`.
- Do NOT shrink the header copy — only the inline one loses detail; the
  header stays the full explanation, minus only the historical clause named
  above.

## VERIFY

1. Nothing outside a comment changed. Count every line that is NOT a `//`
   comment and NOT blank — this bird only edits `//` lines, so that count
   must be identical before and after, whatever the total line count of the
   file does:

   ```bash
   cd /home/lox/code/_fcl/rookery/bibtex/0.1.0/src && grep -cvE "^\s*(//|$)" lib.typ
   ```

   Run it before you start (record the number) and again once you're done —
   the two must be identical.

2. `cd /home/lox/code/_fcl/rookery/bibtex/0.1.0 && just test` must be green,
   output identical to the baseline recorded before this review — a
   comment-only change cannot affect it, so any difference means something
   outside a comment moved.

3. The duplication is gone: `only:` should now stop earlier before the
   implementation, and the inline comment should be shorter:

   ```bash
   grep -n "the whole point is that a library" /home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ
   ```

   Must print no match — that sentence existed only in the inline copy this
   bird shrinks.