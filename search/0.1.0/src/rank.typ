// The tiering rule: a tag expression extracted from the query, the survivors
// scored on name and title, and a second tier scored on body.
//
// `_rank` takes the rows it ranks rather than reading them, which is what lets
// `test/parity.typ` hand it the same fixtures `search` in `src/score.js` gets.
// Every number here has a twin there, and `just parity` diffs the two.

#import "base.typ": *
// Both halves of a query, from the modules that own them: `tagquery.typ` for
// `split-query`/`eval-tag-query`, `score.typ` for `fuzzy-score`/`body-score`.
// This is the one file that needs both, and a module resolves its own imports
// rather than inheriting the manifest's.
#import "tagquery.typ": *
#import "score.typ": *

// ROWS MUST ARRIVE IN ID ORDER, which is what `ideas()` guarantees. Ties within a
// tier fall to Typst's stable sort, i.e. to the incoming order, where the
// JavaScript side breaks them by id explicitly: the two agree for id-ordered
// input and may disagree for anything else, so an arbitrarily ordered corpus is
// outside the parity guarantee and the fixture keeps its rows id-ordered.
//
// THE `tags:` SPLIT LIVES HERE rather than in `#search-ideas`, in the same place
// its JavaScript counterpart splits. That keeps `_rank`'s signature
// `(rows, query, ..)`, so the fixture can diff a TAG QUERY across the two
// languages as data exactly as it diffs a text one, with the parse under test.
//
// Private: the public surface is `#search-ideas`. `test/parity.typ` imports this
// by relative path, as it imports `fuzzy-score`.
#let _rank(rows, query, limit: none, body-search: true) = {
  // SPLIT ONCE, before the loop: a parse costs about 60 microseconds and its
  // answer cannot change between rows.
  //
  // `q` IS THE RESIDUAL TEXT, and every scorer below sees it rather than `query`,
  // or a `tags:draft window` query would hand the literal "tags:draft" to
  // `fuzzy-score` and match nothing.
  //
  // AN EMPTY RESIDUAL IS THE BROWSE LISTING. `fuzzy-score` returns 0 for an empty
  // query, so every surviving note ties at 0 in the name tier, and for `q == ""`
  // — a bare query, or a `tags:`-only one — the tie breaks by date instead:
  // dated notes newest first, undated notes last in id order. That mirrors
  // `_sort-ids` in rookery's `src/pure.typ` over the same `created` field. The
  // body tier is empty for `q == ""` either way, `body-score` returning `none`
  // for an empty query.
  let tq = split-query(query)
  let q = tq.text
  let name-hits = ()
  let body-hits = ()
  for e in rows {
    // FILTER BEFORE SCORING, as the first statement in the loop. `limit:` applies
    // to the FILTERED set, so a limited `tags:` query must not spend its slots on
    // notes the filter rejects. It is also the cheaper order by a wide margin: the
    // pool the body tier walks shrinks before it is walked, which over a synthetic
    // 5000-note corpus is 0.85 ms for `tags:note&draft` against 15.1 ms for a bare
    // "window depth". A negation keeps most of the corpus and so costs the
    // baseline.
    //
    // A TAG MATCH IS A PREDICATE, NOT A SCORER, so `continue` is the only thing it
    // does here: no third tier, no bonus to a score, no effect on the tiering
    // below. Tags decide WHICH notes are candidates, never how they rank.
    //
    // `e.at("tags", default: ())` rather than `e.tags`, mirroring `row.tags ?? []`
    // in the port: this function ranks rows a CALLER supplies, including
    // `test/parity.typ`'s literal corpus, so a row with no `tags` field reads as
    // untagged rather than erroring.
    if tq.rpn.len() > 0 and not eval-tag-query(tq.rpn, e.at("tags", default: ()).map(_fold)) {
      continue
    }
    let s-name = fuzzy-score(e.name, q)
    // SCORED AGAINST `label`, not `text`: `label` is the authored title flattened,
    // else the body's first 60 characters, else the name, so a titleless note is
    // findable by what it says rather than by its id alone. It is never empty,
    // which is why nothing guards for that here.
    let s-text = fuzzy-score(e.label, q)
    let name-score = if s-name == none {
      s-text
    } else if s-text == none { s-name } else { calc.max(s-name, s-text) }
    if name-score != none {
      name-hits.push((..e, score: name-score, kind: "name"))
      continue
    }
    if not body-search { continue }
    let body-score-val = body-score(e.at("body", default: ""), q)
    if body-score-val != none {
      body-hits.push((..e, score: body-score-val, kind: "body"))
    }
  }
  // A REAL SEARCH (`q != ""`) sorts by score descending. AN EMPTY RESIDUAL sorts
  // by date, newest first, the way `_sort-ids` in rookery's `src/pure.typ` does:
  // split into dated and undated — each `.filter` preserving the incoming
  // id-ascending order within its split — walk the dated group's distinct stamps
  // newest to oldest, and append the undated group unchanged at the end.
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
  body-hits = body-hits.sorted(key: e => -1 * e.score)
  let out = name-hits + body-hits
  if limit == none { out } else { out.slice(0, calc.min(limit, out.len())) }
}
