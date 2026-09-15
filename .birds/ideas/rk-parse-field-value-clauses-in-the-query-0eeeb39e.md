---
id: rk-parse-field-value-clauses-in-the-query-0eeeb39e
short-id: 0ee
title: Parse field:value clauses in the query parser
priority: 3
labels:
- type:feature
- search-clause-roles
deps: []
closed: true
---
Teach the query parser to split an atom into a FIELD and a VALUE on its first
unescaped `:`, so `tags:draft` and `status:done` parse as field clauses while a
bare word like `window` stays a text clause. Parser only: what the evaluator
DECIDES must not change in this bird.

## The vocabulary this work uses

The query language is a single tree of CLAUSES, each with a ROLE:

- A **gating clause** decides whether a note is a candidate. It contributes
  nothing to the score. `field:value` is a gating clause.
- A **scoring clause** contributes an integer to the score, and gates as well. A
  bare word is a scoring clause.

This is Lucene's `BooleanClause.Occur` model — MUST gates and scores, FILTER
gates with zero score, SHOULD scores when it matches, MUST_NOT excludes with zero
score:
<https://lucene.apache.org/core/6_2_1/core/org/apache/lucene/search/BooleanClause.Occur.html>

This bird only makes the parser able to TELL the two roles apart. Scores arrive
in the bird that depends on this one.

## What is already in the tree — do not re-derive

- `parse-tag-query` at `/home/lox/code/_fcl/rookery/search/0.1.0/src/tagquery.typ`
  line 58 is a shunting-yard over `src.clusters()`. It accumulates characters into
  a local `atom` string and pushes `("atom", _fold(atom))` at each operator
  boundary. There are FOUR push sites: the `(` branch, the `)` branch, the
  operator branch, and the final flush after the loop.
- Its JavaScript twin is `parseTagQuery` at
  `/home/lox/code/_fcl/rookery/search/0.1.0/src/tagquery.js` line 39.
- `_prec` (`tagquery.typ` line 40) is `("!": 3, "&": 2, "|": 1)`. `:` is NOT an
  operator, so today `status:done` accumulates as the single atom `"status:done"`.
- `\` already escapes the next cluster into the current atom, so `a\:b` must come
  out as one value containing a literal `:`.
- `_fold(s)` in `src/base.typ` lowercases and turns `-` and `_` into spaces. An
  atom is folded WHEN PUSHED, exactly once, and the JS port mirrors that.

## Steps

1. Change the RPN atom token from the 2-tuple `("atom", value)` to the 3-tuple
   `("atom", field, value)`, where `field` is `""` for a bare word. Apply this at
   all four push sites named above.
2. Split on the FIRST unescaped `:` only. Decide the split AS YOU ACCUMULATE
   rather than by re-scanning the finished atom — a re-scan cannot tell an escaped
   `:` from a real one. Accumulate into `field` until the first unescaped `:` is
   seen, then into `value`. So `a:b:c` is field `a`, value `b:c`.
3. Fold the field with `_fold` and the value with `_fold`, as the code folds today.
4. An empty field (`:draft`) is a TEXT clause whose value is the literal `:draft`
   — not a field clause with an empty name.
5. An empty value (`tags:`, which a reader types on the way to `tags:draft`) is a
   field clause with value `""`. Push nothing onto `repaired` for it: it is a valid
   prefix, not a repair.
6. Mirror every one of these decisions in `parseTagQuery` in `tagquery.js`. The two
   sides must emit identical tokens — that is what `just parity` checks.
7. Update `_rpn-str` (`test/parity.typ` line 285) and its twin (`test/parity.mjs`
   line 101) to render the 3-tuple, and add cases to the `<tag-parity>` fixture
   (`test/parity.typ` line 303) covering: `tags:draft`, `status:done`, `window`,
   `a\:b`, `a:b:c`, `:draft`, and a bare `tags:`.

## Callers that must keep working, with behaviour unchanged

- `eval-tag-query` (`tagquery.typ` line 162) and `evalTagQuery` (`tagquery.js`
  line 109) destructure each token as `let (kind, v) = tok`. Adapt the destructure
  so an atom's VALUE still reaches the existing prefix test against a note's tags,
  and IGNORE the field for now.
- `positiveAtoms` (`tagquery.js` line 153), which feeds match highlighting.
- `_rank` (`src/rank.typ` line 65) passes `tq.rpn` straight through.

## Do NOT

- Do not add `:` or any other character to `_prec`.
- Do not change what `eval-tag-query` decides about any note.
- Do not give an unknown field name a meaning yet — that belongs to a later bird.
- Do not touch `split-query` / `splitQuery`.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/search/0.1.0`:

1. `just parity` passes, and its reported case count has grown by the seven new
   fixture cases.
2. `just test` passes.
3. `typst eval --features html --root . --format json 'query(<tag-parity>).first().value' --in test/parity.typ`
   shows `tags:draft` as field `tags` / value `draft`, and `window` as field `""` /
   value `window`.
4. `just build` succeeds.
