---
id: rk-carry-a-score-through-clause-evaluation-8d369f77
short-id: 8d
title: Carry a score through clause evaluation
priority: 3
labels:
- type:feature
- search-clause-roles
deps:
- blocked-by:rk-parse-field-value-clauses-in-the-query-0eeeb39e
closed: false
---
Make clause evaluation return a MATCH and a SCORE instead of a bare boolean, with
the composition rules every production search engine uses. Additive: nothing reads
the score yet, so no ranking changes in this bird.

## The vocabulary and the composition rule

The query language is a single tree of CLAUSES, each with a ROLE:

- A **gating clause** decides whether a note is a candidate and contributes
  nothing to the score. `field:value` is a gating clause.
- A **scoring clause** contributes an integer AND gates. A bare word is a
  scoring clause.

Composition — this is the max-plus (arctic) semiring, and it is exactly what
Lucene's `BooleanQuery` does when it sums the scores of matching MUST and SHOULD
clauses while FILTER and MUST_NOT contribute zero:

| clause      | matched                  | score                        |
|-------------|--------------------------|------------------------------|
| `field:val` | the field predicate      | `0` (gates only)             |
| bare word   | the text scorer hit      | the scorer's integer         |
| `a & b`     | `a.matched and b.matched`| `a.score + b.score`          |
| `a \| b`    | `a.matched or b.matched` | `max` over the MATCHED sides |
| `!a`        | `not a.matched`          | `0` (gates only)             |

References for the semantics, worth reading before starting:

- Lucene clause roles:
  <https://lucene.apache.org/core/6_2_1/core/org/apache/lucene/search/BooleanClause.Occur.html>
- Lucene's additive BM25 across clauses:
  <https://lucene.apache.org/core/9_9_1/core/org/apache/lucene/search/similarities/BM25Similarity.html>
- Xapian's `OP_FILTER`, whose weight is the LEFT side only — the precise
  gates-without-scoring primitive:
  <https://xapian.org/docs/apidoc/html/classXapian_1_1Query.html>

Two rules this table encodes deliberately, because they are what every engine
surveyed does and they are the ones easiest to get wrong:

- A negated clause NEVER contributes a score penalty. It gates and scores zero.
- An `|` branch that did not match costs nothing. There is no partial-credit
  penalty for the unmatched side.

INTEGER ARITHMETIC ONLY. `+` and `max` over integers are exact in both languages,
which is what lets `just parity` diff the two implementations number for number.
Do not normalise to a 0..1 range, do not divide, and do not introduce a float
anywhere.

## What is already in the tree — do not re-derive

- `eval-tag-query(rpn, tags)` at
  `/home/lox/code/_fcl/rookery/search/0.1.0/src/tagquery.typ` line 162 walks the
  RPN with a stack of booleans. An atom pushes a PREFIX test against the note's
  folded tags; `!` pops one and negates; `&`/`|` pop two.
- Its twin is `evalTagQuery` at
  `/home/lox/code/_fcl/rookery/search/0.1.0/src/tagquery.js` line 109.
- Both are LENIENT by contract: an empty RPN means "no filter, everything
  matches", and the two arity guards (`st.len() > 0`, `st.len() >= 2`) SKIP a
  dangling operator rather than failing. That is the other half of "parsing never
  fails", and it must survive this change.
- The prior bird in this label made an atom token the 3-tuple
  `("atom", field, value)`.
- Callers today: `_rank` (`src/rank.typ` line 65), `panel.js` line 286 (per
  keystroke, over `row.allTags`), and `searchSplit` (`src/score.js` line 131).

## Steps

1. Add `eval-clauses(rpn, resolve)` to `tagquery.typ`, and `evalClauses(rpn,
   resolve)` to `tagquery.js`. `resolve` is a caller-supplied function taking
   `(field, value)` and returning a `(matched, score)` pair — a dictionary
   `(matched: bool, score: int)` in Typst and an object `{matched, score}` in
   JavaScript. Injecting the resolver is what keeps this module free of any
   knowledge of tags, text or rows, so `_rank` and `panel.js` can each supply
   their own without a second copy of the walk.
2. Walk the RPN exactly as `eval-tag-query` does now, but with a stack of
   `(matched, score)` pairs and the composition table above.
3. Keep both arity guards. An underflowed stack falls back to
   `(matched: true, score: 0)` — the same answer an empty RPN gives.
4. Keep `eval-tag-query` / `evalTagQuery` as they are, and reimplement each as a
   thin call to the new function with a `resolve` that does today's tag prefix test
   and returns score `0`. Their behaviour must be bit-identical afterwards, which
   the existing fixture already checks.
5. Export the new names from `src/lib.typ` (via `tagquery.typ`'s `*` re-export,
   which needs no edit) and from `src/search.js` — note that `search.js` both
   imports AND re-exports these names, because the global published at the bottom
   of that file names them; follow the pattern already there for `evalTagQuery`.
6. Add a `<clause-parity>` fixture to `test/parity.typ` and its reader to
   `test/parity.mjs`, shaped like the existing `<tag-parity>` block at
   `test/parity.typ` line 303. Each case is an RPN plus a table of clause
   resolutions, and the diffed value is the resulting `(matched, score)`. Cover at
   minimum: `a & b` with both matching, `a | b` with only the right side matching,
   `!a`, a gating clause ANDed with a scoring clause, and a dangling operator.

## Do NOT

- Do not change `_rank`, `searchSplit`, `panel.js` or any ranking behaviour. This
  bird is additive; the switchover is the next bird.
- Do not change `split-query` / `splitQuery`.
- Do not delete `eval-tag-query` / `evalTagQuery`.
- Do not introduce a float, a division, or a 0..1 normalisation.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/search/0.1.0`:

1. `just parity` passes, including the new `<clause-parity>` cases.
2. `just test` passes, unchanged — no existing test needed editing.
3. In the new fixture, `a | b` where only `b` matched scores exactly `b`'s score,
   and `!a` over a matching `a` yields `(matched: false, score: 0)`.
4. `just build` succeeds.