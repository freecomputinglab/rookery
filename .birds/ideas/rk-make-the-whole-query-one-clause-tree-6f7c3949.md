---
id: rk-make-the-whole-query-one-clause-tree-6f7c3949
short-id: 6f7
title: Make the whole query one clause tree
priority: 3
labels:
- type:feature
- search-clause-roles
deps:
- blocked-by:rk-carry-a-score-through-clause-evaluation-8d369f77
closed: true
---
Make the WHOLE query one clause tree, so a field predicate and a ranked text term
can be combined with `&`, `|` and `!`. This is the switchover bird: after it,
`tags:draft | window` is expressible and `tags:` no longer has to open a query.

## What the language becomes

One tree of CLAUSES, each with a ROLE. A gating clause (`field:value`) decides
candidacy and scores zero; a scoring clause (a bare word) contributes an integer
and gates. `&` adds scores, `|` takes the max over matched sides, `!` gates with
zero score. That is Lucene's clause-role model:
<https://lucene.apache.org/core/6_2_1/core/org/apache/lucene/search/BooleanClause.Occur.html>

The two prior birds in this label built the pieces: the parser emits
`("atom", field, value)` tokens, and `eval-clauses(rpn, resolve)` /
`evalClauses(rpn, resolve)` walk an RPN returning `(matched, score)`. This bird
wires them to the ranker and retires the residual-text split.

## What is already in the tree — do not re-derive

- `split-query` at
  `/home/lox/code/_fcl/rookery/search/0.1.0/src/tagquery.typ` line 193 tests for a
  leading `tags:` (case-insensitively, after trimming leading whitespace only). If
  absent it returns an empty RPN and the WHOLE query as `text`. If present it
  parses up to the first unescaped space and returns the remainder as `text`.
- Its twin is `splitQuery` at `src/tagquery.js` line 100, with `TAG_PREFIX` at
  line 22.
- Inside `parse-tag-query`, an unescaped space currently ENDS the expression: the
  `c.trim() == ""` branch sets `residual` and `stop = true`.
- `_rank` at `src/rank.typ` line 29 calls `split-query` once (line 44), takes
  `q = tq.text` (line 45), uses the RPN as a pure predicate with `continue`
  (line 65), then scores `q` with `fuzzy-score` over `e.name` and `e.label` and
  with `body-score` over `e.body`.
- `searchSplit` at `src/score.js` line 131 and `search` at line 159 are the
  JavaScript twins; `just parity` diffs `_rank` against `search`.
- `positiveAtoms` at `src/tagquery.js` line 153 collects the non-negated atoms
  that match highlighting marks; it is consumed by `bar.js` line 55, `modal.js`
  line 141 and `row.js` line 29.
- `panel.js` line 262 splits per keystroke and line 286 uses the RPN as a
  predicate over `row.allTags`.

## Steps

1. Make an unescaped SPACE an implicit-AND operator in `parse-tag-query` instead
   of the end of the expression. Remove the `residual` / `stop` machinery. Emit the
   space as the same `&` operator token through the existing precedence loop, and
   emit it ONLY where an atom or a `)` precedes it and an atom, `!` or `(` follows
   — so runs of spaces and leading or trailing spaces emit nothing at all.
   Giving it precedence 2, the same as explicit `&`, is correct and needs no new
   entry in `_prec`: `&` is associative, so the only observable case is `a|b c`,
   which must parse as `a | (b & c)`. Implicit AND binding tighter than `|` is the
   rule SQLite FTS5 states in its grammar, whose precedence table is worth
   copying: <https://www.sqlite.org/fts5.html>
2. `split-query` now parses the whole query and returns `(rpn, repaired)` — there
   is no `text` key any more. Delete `TAG_PREFIX` and the prefix test. Keep
   `split-query` as the single entry point a UI calls.
3. In `_rank`, replace the predicate-then-score sequence with ONE `eval-clauses`
   call per row, passing a `resolve(field, value)` closure that:
   - for a non-empty `field`, does the existing folded PREFIX test against the
     row's tags when the field is `tags`, and returns `(matched: false, score: 0)`
     for a field name it does not know — an unknown field must not silently match
     everything;
   - for an empty `field`, scores the value as text and returns its integer.
4. Treat a note id's colon correctly. Rookery ids are shaped `idea:flat-ids`, so a
   reader typing `idea:flat` would otherwise become a field clause on the unknown
   field `idea` and match nothing. Make an UNKNOWN field name fall back to a TEXT
   clause over the whole unsplit `field:value` string. Say so in the code comment:
   this is the one rule that keeps ids findable.
5. Mirror steps 1–4 in `tagquery.js` and `score.js` (`searchSplit` / `search`).
6. Restrict `positiveAtoms` to TEXT clauses — a gating clause marks nothing,
   because there is no body text for it to highlight. Keep its existing rule that a
   negated atom marks nothing.
7. Update `panel.js` line 286 to call `evalClauses` with its own `resolve` over
   `row.allTags` plus the panel's `data-` fields, and to keep filtering on
   `matched` alone. The panel does not rank, so it ignores the score.
8. Update the `<tag-parity>` and `<clause-parity>` fixtures and add `<rank-parity>`
   cases for the newly expressible queries: `tags:draft | window`,
   `tags:draft window`, `window depth`, `!tags:draft window`, and a bare `tags:`.

## Do NOT

- Do not change `fuzzy-score` / `score` or `body-score` / `bodyScore`. Their
  numbers stay exactly as they are; this bird only changes how those numbers are
  combined.
- Do not change the two-tier name/body rule yet — that is the next bird. For now
  keep `_rank`'s existing tiering by treating the tier as a property of the row, as
  today.
- Do not add `AND` / `OR` / `NOT` keyword spellings — that is a separate bird.
- Do not make `split-query` fail on any input. Every prefix of a valid query gets
  typed on the way to it, so a half-typed query must still parse and rank. This is
  the same posture Elasticsearch ships as `simple_query_string`, which never throws
  and silently drops the fragment it cannot parse:
  <https://www.elastic.co/guide/en/elasticsearch/reference/8.19/query-dsl-query-string-query.html>

## VERIFY

Run from `/home/lox/code/_fcl/rookery/search/0.1.0`:

1. `just parity` passes, including the new `<rank-parity>` cases.
2. `just test` passes.
3. `#context search-ideas("tags:draft | window")` returns notes tagged `draft`
   AND notes whose title matches "window", and a note that satisfies both scores
   higher than one that satisfies only the text side.
4. `#context search-ideas("idea:flat")` still finds the note with id
   `idea:flat-ids` — the unknown-field fallback from step 4.
5. `just build` succeeds and the demo project compiles with `rheo compile`.