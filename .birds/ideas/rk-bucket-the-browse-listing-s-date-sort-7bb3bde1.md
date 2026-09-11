---
id: rk-bucket-the-browse-listing-s-date-sort-7bb3bde1
short-id: 7b
title: Bucket the browse listing's date sort
priority: 4
labels:
- chore-search-review
deps: []
closed: false
---
`_rank`'s browse listing — every empty-residual query, which is what a bare
`tags:draft` and an empty search box both produce — formats each row's date
between three and N+2 times to order the list once.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/src/rank.typ

## What is wrong

`/home/lox/code/_fcl/rookery/search/0.1.0/src/rank.typ` lines 92-103 read:

```typ
  name-hits = if q != "" {
    name-hits.sorted(key: e => -1 * e.score)
  } else {
    let stamp-of(e) = _date-stamp(e.at("created", default: none))
    let dated = name-hits.filter(e => stamp-of(e) != none)
    let undated = name-hits.filter(e => stamp-of(e) == none)
    let ordered = ()
    for s in dated.map(stamp-of).dedup().sorted().rev() {
      ordered += dated.filter(e => stamp-of(e) == s)
    }
    ordered + undated
  }
```

`stamp-of` calls `_date-stamp` (`src/base.typ:91`), which is a
`datetime.display` call. It runs once per row in each of the two filters, once
per row in the `.map`, and then once per dated row for EVERY distinct date in
the result — so for N rows over D distinct dates the count is `3N + N·D`. The
empty residual is not a corner case: it is the whole corpus listing the modal
shows on open, and every `tags:`-only query.

The ordering itself is correct and must not change. Its guarantees, stated in
the comment above it: dated rows newest first, undated last, ties within one
date in the incoming id-ascending order.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Decisions already made — do not re-derive

- **Keep the grouping; drop the recomputation.** The comment records why this is
  not a single `.sorted(key:)`: the tie within a date must stay in the incoming
  order, and it mirrors `_sort-ids` in `@rookery/core`'s `src/pure.typ`. Do not
  replace it with a comparator.
- **Group through a dictionary keyed by stamp**, then walk `.keys().sorted().rev()`.
  Because `name-hits` arrives id-ordered and dictionary insertion appends, each
  bucket comes out id-ascending for free — the property the current `filter`
  relies on — and the explicit `.sorted()` on the keys means nothing depends on
  dictionary key order.
- **This is a Typst-side-only change and it is NOT part of the parity contract.**
  The JavaScript twin of this ordering is `dateCmp` in `src/score.js:118-123`,
  which is a comparator rather than a grouping pass, and the two already differ
  in shape while agreeing on the answer. Do not touch `score.js`, and do not
  "align" the two implementations.

## Steps

1. In `/home/lox/code/_fcl/rookery/search/0.1.0/src/rank.typ`, replace the `else`
   branch quoted above with:

   ```typ
     let buckets = (:)
     let undated = ()
     for e in name-hits {
       // One `display()` per row: formatting the datetime is the cost, and the
       // grouping below would otherwise redo it once per row per distinct date.
       let s = _date-stamp(e.at("created", default: none))
       if s == none { undated.push(e) } else {
         buckets.insert(s, buckets.at(s, default: ()) + (e,))
       }
     }
     // Each bucket is already id-ascending — `name-hits` is, and appending keeps
     // it — so a date-descending walk of the keys yields id-ascending ties.
     let ordered = ()
     for s in buckets.keys().sorted().rev() { ordered += buckets.at(s) }
     ordered + undated
   ```

2. Keep the comment above the branch (lines 87-91) and the one at lines 37-43
   that describes the browse order. Adjust only a sentence that stops being true
   of the mechanism; every claim about the ORDER stays.

## Do NOT

- Do not change the observable ordering in any way.
- Do not touch the `q != ""` branch, the tiering, `limit:`, or the tag
  predicate above them.
- Do not touch `src/score.js` or any other JavaScript file.
- Do not reword comments outside this branch — a separate bird covers this
  package's comment prose.
- Do not edit anything under `test/`.

## VERIFY

All three of these are green today and must stay green:

```sh
cd /home/lox/code/_fcl/rookery/search/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/search/0.1.0 && just parity
cd /home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo && just check
```

Expected: `just test` reports `pass 123` / `fail 0`; `just parity` prints six
`OK` lines ending `generated body parity OK across 150 cases`; the demo ends
`demo/rheo OK`.

`just parity` is the decisive one: its `tier parity OK across 13 cases` feeds
identical fixtures through `_rank` and `search`/`searchSplit` and diffs the
resulting order, so a changed browse order fails it. The demo's
`label: 'marginalia' ranks [...]` line exercises the same path through a real
build.