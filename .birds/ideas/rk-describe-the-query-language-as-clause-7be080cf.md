---
id: rk-describe-the-query-language-as-clause-7be080cf
short-id: 7be
title: Describe the query language as clause roles
priority: 2
labels:
- type:feature
- search-clause-roles
deps:
- blocked-by:rk-tier-each-text-clause-instead-of-the-55b7f0f0
- blocked-by:rk-accept-and-or-not-and-a-leading-dash-fbf676d5
closed: false
---
Rewrite the query language's prose — file headers, comments and the readme — so it
describes the language as a tree of CLAUSES WITH ROLES rather than as a tag filter
plus a residual text query, and name the prior art it borrows from.

## Why the prose has to change and not just the code

The existing comments describe a shape the code no longer has. `tagquery.typ`'s
header calls itself "the `tags:` query language: a boolean expression over a note's
tags"; `rank.typ` explains that "`q` IS THE RESIDUAL TEXT" and that "A TAG MATCH IS
A PREDICATE, NOT A SCORER, so `continue` is the only thing it does here";
`lookup.typ` documents "A LEADING `tags:` IN THE QUERY IS A FILTER, extracted
before any scoring". After the prior birds in this label, all of that is describing
a previous design. A reader arriving cold gets the wrong model of the code in front
of them.

This repo's comment style is in `/home/lox/code/_fcl/rookery/CLAUDE.md` and it
governs this bird: describe the PRESENT, never what the code used to be, what
moved, or which version changed it. So this is a rewrite in place, not a changelog
— no "formerly a residual text query", no "this used to be a filter".

## The vocabulary to standardise on

- A query is one tree of **clauses**.
- A **gating clause** decides whether a note is a candidate and contributes
  nothing to the score. `field:value` is a gating clause.
- A **scoring clause** contributes an integer to the score and gates as well. A
  bare word is a scoring clause.
- `&` adds the scores of both sides, `|` takes the max over the sides that
  matched, `!` gates and scores zero.
- The **tier** (name or body) is an outer sort key over the score, not a term
  added into it.

Use these words consistently. "Filter", "predicate" and "residual" should not
appear as competing names for the same ideas once this bird is done.

## Files to change

1. `/home/lox/code/_fcl/rookery/search/0.1.0/src/tagquery.typ` — the file header
   (lines 1–9) and the grammar block above `parse-tag-query` (around lines 12–56).
2. `/home/lox/code/_fcl/rookery/search/0.1.0/src/tagquery.js` — the same, in its
   own header and around `parseTagQuery`.
3. `/home/lox/code/_fcl/rookery/search/0.1.0/src/rank.typ` — the header and the
   in-loop comments at and around lines 44–65.
4. `/home/lox/code/_fcl/rookery/search/0.1.0/src/score.js` — the header, and the
   comments on `searchSplit` (line 131).
5. `/home/lox/code/_fcl/rookery/search/0.1.0/src/lookup.typ` — the `#search-ideas`
   documentation block, including the worked query examples around lines 12–40.
6. `/home/lox/code/_fcl/rookery/search/0.1.0/readme.md` — the query language
   section. Line 235 currently says "up to the first unescaped space is a boolean
   expression over each note's own [tags]", which is no longer true; line 1290
   cross-references the same language from the panel documentation.
7. `/home/lox/code/_fcl/rookery/search/0.1.0/src/lib.typ` — the entrypoint header
   summarising the two layers, if its wording still implies a tags-prefixed filter.

## Links to include

Put these in the file header of `tagquery.typ` and its JavaScript twin, and in the
readme's query language section. The repo's comment style allows a comment to name
its counterpart in the other language and the rule that pins them; a URL naming
where the semantics come from is the same kind of present-tense fact about how the
code is arranged.

- Lucene's clause roles — MUST gates and scores, FILTER gates with zero score,
  SHOULD scores when it matches, MUST_NOT excludes with zero score. This is the
  model the language implements:
  <https://lucene.apache.org/core/6_2_1/core/org/apache/lucene/search/BooleanClause.Occur.html>
- Lucene's classic query syntax, for the `field:value` plus `AND`/`OR`/`NOT`
  spelling:
  <https://lucene.apache.org/core/8_0_0/queryparser/org/apache/lucene/queryparser/classic/package-summary.html>
- SQLite FTS5's grammar and precedence table, which is where the rule that
  implicit AND binds tighter than every explicit operator comes from:
  <https://www.sqlite.org/fts5.html>
- Xapian's `OP_FILTER`, whose weight is the left side only — the precise
  gates-without-scoring primitive:
  <https://xapian.org/docs/apidoc/html/classXapian_1_1Query.html>

Keep each link to one line with a short clause saying what it is for. A bare URL
with no reason attached is worth nothing to the next reader.

## Steps

1. Rewrite each file's header and the affected comment blocks in the vocabulary
   above. One header per file; do not add interior `// ---- Section ----` banners.
2. Update every worked query example so it shows something the language now does.
   `lookup.typ`'s examples in particular should include a recombined query such as
   `tags:draft | window`, which is the case the whole label exists to make possible.
3. Document the two composition rules that are easy to get wrong, because both are
   deliberate and both match every engine surveyed: a negated clause never
   contributes a score penalty, and an `|` branch that did not match costs nothing.
4. Document the unknown-field fallback and why it exists: rookery ids are shaped
   `idea:flat-ids`, so an unknown field name falls back to a text clause over the
   whole `field:value` string, which is what keeps ids findable.
5. Keep the parity note that already exists — `tagquery.typ` naming
   `src/tagquery.js`, `score.typ` naming `src/score.js`, and `just parity` as what
   pins them. That is the standing exception in the comment style and it stays.
6. Keep every measurement already recorded and the reason it is there: the 60
   microsecond parse cost, the 0.85 ms against 15.1 ms filter-before-scoring
   figure, 48 body terms, the 40% document-frequency ceiling.

## Do NOT

- Do not change a single line of executable code. This bird is prose only. If a
  comment turns out to be describing a real bug, file a separate bird rather than
  fixing it here.
- Do not name a bird, a bookmark or a branch anywhere in the prose.
- Do not write what the design used to be, what moved, or which version changed
  it.
- Do not add a link without a clause saying what it is for.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/search/0.1.0`:

1. `rg -n 'residual' src/ readme.md` returns nothing that describes the query
   language's shape.
2. `rg -n 'BooleanClause|fts5|Xapian' src/tagquery.typ src/tagquery.js readme.md`
   shows the links present in all three.
3. `jj diff --stat` shows changes only to comments, the readme, and no change to
   any executable line — confirm by reading the diff.
4. `just parity`, `just test` and `just build` all still pass, unchanged.