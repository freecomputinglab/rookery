// The ranking rule in Typst: the subsequence matcher over a note's id and title,
// and the AND term matcher over its compressed body.
//
// The Typst half of `src/score.js`. The two are pinned case for case by
// `test/parity.mjs`, including a generated suite that hunts for disagreements, so
// every number here has a twin there: change one, change the other, and re-run
// `just parity` before believing either.

#import "base.typ": *

// Subsequence fuzzy match: `none` when `query`'s characters do not all appear in
// `hay` in order, otherwise an integer score, higher is better. An empty query
// matches everything at score 0.
//
// The score is 1 point per matched character, 3 instead when it sits immediately
// after the previous match, so a contiguous run beats a scatter; +10 for a prefix
// match, else +5 for a substring match anywhere; up to +5 for matching near the
// start; and up to +10 for the haystack being close in length to the query.
//
// That last term is the only one rewarding a match over a large FRACTION of the
// hay, and it is what separates a near-exact hit from a longer one: without it
// "window" scores `windows` and `window-depth` identically at 31, both being
// six-character prefix matches, and the tie falls to the id. With it they are 40
// and 35.
//
// Integer arithmetic throughout: `score` in `src/score.js` computes this rule for
// the live bar, and integers compare exactly across the two languages where
// floats would not.
#let fuzzy-score(hay, query) = {
  let h = _fold(hay)
  let q = _fold(query)
  if q == "" { return 0 }
  let hc = h.clusters()
  let qc = q.clusters()
  let i = 0
  let first = none
  let prev = none
  let points = 0
  for ch in qc {
    let found = none
    let j = i
    while j < hc.len() {
      if hc.at(j) == ch { found = j; break }
      j += 1
    }
    if found == none { return none }
    if first == none { first = found }
    points += if prev != none and found == prev + 1 { 3 } else { 1 }
    prev = found
    i = found + 1
  }
  if h.starts-with(q) { points += 10 } else if h.contains(q) { points += 5 }
  points += calc.max(0, 5 - first)
  points += calc.max(0, 10 - (hc.len() - qc.len()))
  points
}

// AND match over a note's body: `none` unless every whitespace-split term in
// `query` appears as a substring of some SPACE-SEPARATED TERM of `body`,
// otherwise an integer score, higher is better. Not `fuzzy-score`, which is a
// subsequence matcher — good over a 40-character id, noise over a body, where its
// length term clamps to 0 for nearly everything.
//
// `body` IS A TERM LIST wherever the browser calls this: what `#search-index`
// ships is `_compress-corpus`' output, a note's most distinctive terms
// space-joined in weight order. `#search-ideas` calls the same function on full
// prose, where a "term" is simply a word and the rule degrades to word-position
// earliness.
//
// AND across terms keeps a multi-word query from behaving like an OR and dragging
// in the whole corpus. Matching is by SUBSTRING per term, so a prefix query still
// lands: `justif` finds `justification`, `0.5` finds `0.5.1`.
//
// THE SCORE IS RANK, because in a compressed body position is the weight and no
// weights are shipped. Per query term: `max(1, 10 - int(rank / 4))`, where `rank`
// is the index of the first kept term containing it, plus 3 when the query term IS
// a kept term exactly. The exact-match bonus tests membership of the whole list
// rather than equality with the term at `rank`, so a prefix hit high up does not
// cost a note the bonus its exact term earns further down. A rank is a term index,
// which both languages count identically, so no offset arithmetic can drift.
//
// `lower`, NOT `_fold`, and the difference is load-bearing: `_fold` turns `-` and
// `_` into spaces, which would split `rheo-context` — the exact token `_tokenize`
// works to preserve — into two query terms and destroy the exact-match +3. Little
// is lost, matching being per-term substring: "flat ids" still finds the term
// `flat-ids`. What is lost is the reverse, "flat-ids" typed at a body spelling it
// as two words, and that trade buys exact-term scoring.
//
// BOTH SIDES SPLIT ON A LITERAL SPACE, not on whitespace generally, and neither
// side may be "fixed" alone. `_compress-corpus` joins with a space, so the
// browser's input never holds anything else; a full prose body from
// `#search-ideas` can hold a newline, which then sits inside a term and only
// coarsens its rank. Typst's `split(" ")` and JavaScript's `split(" ")` treat that
// identically where a whitespace regex on one side would not.
//
// Integer arithmetic throughout, same reason as `fuzzy-score`: `bodyScore` in
// `src/score.js` computes the same rule and `just parity` diffs the two number
// for number.
#let body-score(body, query) = {
  let h = lower(body)
  let q = lower(query)
  if q.trim() == "" { return none }
  let terms = q.split(" ").filter(t => t != "")
  if terms.len() == 0 { return none }
  let kept = h.split(" ").filter(t => t != "")
  let points = 0
  for term in terms {
    let rank = none
    let i = 0
    while i < kept.len() {
      if kept.at(i).contains(term) { rank = i; break }
      i += 1
    }
    if rank == none { return none }
    points += calc.max(1, 10 - int(rank / 4))
    if kept.contains(term) { points += 3 }
  }
  points
}
