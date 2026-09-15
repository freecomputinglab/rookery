---
id: rk-accept-and-or-not-and-a-leading-dash-fbf676d5
short-id: fb
title: Accept AND, OR, NOT and a leading dash
priority: 1
labels:
- type:feature
- search-clause-roles
deps:
- blocked-by:rk-make-the-whole-query-one-clause-tree-6f7c3949
closed: true
---
Accept `AND`, `OR`, `NOT` and a leading `-` as spellings of `&`, `|` and `!`, so
the query language matches the syntax readers already know from other search
boxes.

## Why both spellings and not one

Lucene, Xapian and Bleve all accept the terse symbol form AND the keyword form
simultaneously, and that is the field's settled answer rather than an oversight:

- Lucene's classic parser takes `AND` / `OR` / `NOT` as well as `+` / `-`:
  <https://lucene.apache.org/core/8_0_0/queryparser/org/apache/lucene/queryparser/classic/package-summary.html>
- Xapian's parser takes `AND OR NOT XOR NEAR` alongside `+` / `-`:
  <https://xapian.org/docs/apidoc/html/classXapian_1_1QueryParser.html>

The keyword form is the discoverable one; the symbols are the shortcut for
someone who has learned them. There is evidence a terse operator alone does not
get learned: when Google retired `+` in 2011 it reported the operator appeared in
under 0.5% of searches and that two thirds of those uses were wrong.

## What is already in the tree — do not re-derive

- `_prec` at `/home/lox/code/_fcl/rookery/search/0.1.0/src/tagquery.typ` line 40 is
  `("!": 3, "&": 2, "|": 1)`, and the tokenizer tests membership with `c in _prec`
  on a SINGLE cluster. A multi-character keyword cannot come out of that test as it
  stands.
- `parse-tag-query` at line 58 accumulates non-operator clusters into an atom, so
  `AND` currently parses as an atom with the value `and`.
- Its twin is `parseTagQuery` at `src/tagquery.js` line 39, with `PREC` mirroring
  `_prec`.
- The escape set is `( ) | & ! \` and the file states it is FROZEN — a tag holding
  one of those must be escapable, and promoting a new character to an operator
  would change what already-written queries mean. Adding a KEYWORD does not touch
  that set, which is why this bird is safe; adding a new symbol would not be.
- An earlier bird in this label made an unescaped space an implicit-AND operator.

## Steps

1. When an atom is about to be pushed, test whether its unfolded text is exactly
   `AND`, `OR` or `NOT`, case-insensitively. If it is, emit the corresponding
   operator token (`&`, `|`, `!`) through the existing precedence loop instead of
   an atom token. Doing the test at PUSH time rather than in the tokenizer is what
   keeps the single-cluster `c in _prec` test intact and the diff small.
2. A keyword must be a whole word to count. `android` is an atom, not `AND` plus
   `roid`. Because the test runs on a complete accumulated atom, this falls out
   for free — say so in a comment so nobody reintroduces a substring test.
3. An escaped keyword is an atom: `\AND` searches for the word "and". The escape
   already forces its cluster into the atom, so make the keyword test skip any
   atom that consumed an escape. Track that with a flag set in the `\` branch.
4. Accept a leading `-` on a clause as `!`: `-tags:draft` is `!tags:draft`, and
   `window -depth` is `window & !depth`. Recognise it only where the `-` opens an
   atom (nothing accumulated yet and an operator or the start of input precedes
   it), so a `-` INSIDE a word stays part of the word. This matters: `_fold` turns
   `-` into a space, and `in-progress` must keep working as a value.
5. Mirror every rule in `parseTagQuery` in `tagquery.js`.
6. Add `<tag-parity>` fixture cases in `test/parity.typ` for: `a AND b`,
   `a and b`, `a OR b`, `NOT a`, `android`, `\AND`, `-tags:draft`,
   `window -depth`, and `in-progress`.

## Do NOT

- Do not add any new character to the escape set or to `_prec`'s keys. The escape
  set is frozen and widening it is a breaking change to queries already written.
- Do not add `+` as a synonym for `&`. A leading `-` earns its place because it is
  near-universal for negation; `+` does not, and the Google data above is the
  reason.
- Do not add `XOR`, `NEAR`, phrase quoting or ranges. Each is its own decision.
- Do not change precedence. `NOT` takes `!`'s precedence 3, `AND` takes 2, `OR`
  takes 1, and `!`'s right-associativity rule at equal precedence stays exactly as
  written.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/search/0.1.0`:

1. `just parity` passes, including the nine new fixture cases.
2. `just test` passes.
3. `#context search-ideas("tags:draft AND window")` and
   `#context search-ideas("tags:draft & window")` return identical rows in
   identical order.
4. `#context search-ideas("android")` still matches the note whose name contains
   "android", and `#context search-ideas("in-progress")` still matches the tag
   `in-progress`.
5. `just build` succeeds.