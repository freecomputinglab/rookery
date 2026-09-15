---
id: rk-tier-each-text-clause-instead-of-the-55b7f0f0
short-id: '55'
title: Tier each text clause instead of the whole row
priority: 2
labels:
- type:feature
- search-clause-roles
deps:
- blocked-by:rk-make-the-whole-query-one-clause-tree-6f7c3949
closed: false
---
Make the name/body tier a property of each TEXT CLAUSE rather than of the whole
row, so tiering survives a query with more than one text clause in it.

## Why this bird exists

`#search-ideas` returns two tiers, and the reason is written down in
`/home/lox/code/_fcl/rookery/search/0.1.0/src/lookup.typ`: a title match and a
body match are not the same kind of evidence, so a note found by name must not be
pushed below a note that merely mentions the word. A weighted sum would only
approximate that and would need retuning. That argument still holds and this bird
must not trade it away.

What changed is that a query can now hold several text clauses
(`window & depth`, `tags:draft | window`), so "the tier of the row" is no longer
well defined. The tier has to be computed per clause and then reduced.

## What is already in the tree — do not re-derive

- `_rank` at `/home/lox/code/_fcl/rookery/search/0.1.0/src/rank.typ` line 29
  scores `fuzzy-score(e.name, q)` and `fuzzy-score(e.label, q)`, takes the better
  of the two as the name-tier score, and only if BOTH are `none` falls through to
  `body-score(e.body, q)`. It pushes rows into `name-hits` with `kind: "name"` or
  `body-hits` with `kind: "body"`, sorts each by score descending, and concatenates
  name-hits ahead of body-hits.
- `kind` is part of the public row shape `#search-ideas` returns, and the modal's
  preview pane reads it. Its two values must stay `"name"` and `"body"`.
- For an empty query the name tier ties at 0 and the order falls to date — dated
  newest first via `_date-stamp`, undated last in id order. That path must survive.
- `searchSplit` at `src/score.js` line 131 is the twin `just parity` diffs against
  `_rank`.
- The prior bird made `_rank` resolve each clause through a
  `resolve(field, value)` closure handed to `eval-clauses`.

## Steps

1. In `_rank`'s `resolve` closure, score a text clause by trying the name tier
   first — `max` of `fuzzy-score(e.name, value)` and `fuzzy-score(e.label, value)`
   — and only when both are `none` trying `body-score(e.body, value)`. Return the
   integer plus which tier produced it.
2. Accumulate the tier alongside the score as the clause tree is walked. Reduce it
   as: a row's tier is `"name"` if ANY text clause that MATCHED scored in the name
   tier, otherwise `"body"`. A row with no matched text clause at all — a pure
   gating query like `tags:draft` — keeps `kind: "name"`, which is what the current
   browse listing already produces and what the date ordering in step 4 depends on.
   Carry the tier on the same `(matched, score)` pair the walk already threads, so
   there is no second walk.
3. Sort with the TIER as the outer key and the score as the inner key: every
   `kind: "name"` row ahead of every `kind: "body"` row, each group by score
   descending. Keep the existing two-array-then-concatenate shape if that is the
   smaller diff — it already produces exactly this order.
4. Keep the empty-query path exactly as it is: when the query has no text clause,
   the name tier ties at 0 and the order falls to date, dated newest first and
   undated last in id order.
5. Mirror all of it in `searchSplit` in `src/score.js`. The JavaScript side breaks
   ties by id explicitly where Typst relies on a stable sort over id-ordered input;
   that existing asymmetry is documented in `rank.typ` and stays as it is.
6. Extend `<rank-parity>` in `test/parity.typ` with cases that pin the reduction:
   one text clause matching in the name tier and another in the body tier on the
   same row; a row matching only in the body tier; a pure gating query; and an
   empty query, to prove the date ordering did not move.

## Do NOT

- Do not blend the tiers into one number. The tier is an outer sort key, not a
  bonus added to the score. This is the whole argument in `lookup.typ` and the
  reason not to adopt a weighted sum.
- Do not add a third tier, and do not let a gating clause influence the tier.
- Do not change `fuzzy-score` or `body-score`, or the `kind` field's two values.
- Do not touch the island format or `_compress-corpus`.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/search/0.1.0`:

1. `just parity` passes, including the new tier-reduction cases.
2. `just test` passes.
3. `#context search-ideas("window depth")` puts every row whose name or title
   matched above every row matched only in its body, and both groups are score-
   ordered within themselves.
4. `#context search-ideas("")` returns the browse listing unchanged — dated notes
   newest first, undated last in id order.
5. `just build` succeeds and the demo project compiles with `rheo compile`.