// The tiering rule: a row's tags gate it, each of its text clauses scores
// against name/title first and body only on a name-tier miss, and the row's
// overall tier is the best tier any of its matched text clauses reached.
//
// `_rank` takes the rows it ranks rather than reading them, which is what lets
// `test/parity.typ` hand it the same fixtures `search` in `src/score.js` gets.
// Every number here has a twin there, and `just parity` diffs the two.

#import "base.typ": *
// Both halves of a query, from the modules that own them: `tagquery.typ` for
// `split-query`/`eval-clauses`, `score.typ` for `fuzzy-score`/`body-score`.
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
// THE QUERY IS PARSED HERE rather than in `#search-ideas`, in the same place
// its JavaScript counterpart parses it. That keeps `_rank`'s signature
// `(rows, query, ..)`, so the fixture can diff a whole clause tree across the
// two languages as data exactly as it diffs a text one, with the parse under
// test.
//
// Resolves one CLAUSE against one row, for `eval-clauses`: a `tags:` field is
// the folded-prefix gate `eval-tag-query` also runs, scoring `0` and carrying
// tier `"none"`; every other field NAMES A TEXT CLAUSE, tried against the NAME
// tier first and the BODY tier only if that comes back `none` — the same
// fallback that lets a note id like `idea:flat-ids` stay findable as
// `idea:flat` even though `idea` names no field this module knows. A bare word
// (`field == ""`) is the SAME fallback with an empty prefix, so it needs no
// separate branch.
//
// `name-score` is `fuzzy-score` against `e.name`/`e.label`/`e.id`,
// `body-score` against `e.body` — the same two rules `_rank` always scored,
// now called once per TEXT CLAUSE (each trying name then body) rather than
// once over the whole row with the tier fixed in advance. `body-search:
// false` is threaded in here rather than skipped by the caller, so a row
// failing the name tier on every clause never reaches `body-score` at all —
// `eval-clauses` still walks the SAME tree either way.
//
// The result CARRIES which tier scored the clause — `"name"` or `"body"`,
// `"none"` for a gate or a miss — which is what lets `eval-clauses` reduce a
// row with clauses split across both tiers to ONE tier rather than blending
// their scores. See its own comment for the reduction rule.
//
// The best of several `fuzzy-score`/`body-score` answers, `none` unless at
// least one of them is — the same none-coalescing `_rank` always did for its
// name/label pair, generalised to as many haystacks as a caller has.
#let _best(scores) = {
  let hits = scores.filter(s => s != none)
  if hits.len() == 0 { none } else { calc.max(..hits) }
}

#let _resolve(name-score, body-score, tags, body-search) = (field, value) => {
  if field == "tags" {
    // AN EMPTY VALUE IS NO CONSTRAINT: see `eval-tag-query`'s own comment for
    // why a bare `tags:` must not read as "tagged with the empty string".
    (matched: value == "" or tags.any(tg => tg == value or tg.starts-with(value)), score: 0, tier: "none")
  } else {
    let text = if field == "" { value } else { field + ":" + value }
    let ns = name-score(text)
    if ns != none {
      (matched: true, score: ns, tier: "name")
    } else if body-search {
      let bs = body-score(text)
      if bs == none { (matched: false, score: 0, tier: "none") } else { (matched: true, score: bs, tier: "body") }
    } else {
      (matched: false, score: 0, tier: "none")
    }
  }
}

// Private: the public surface is `#search-ideas`. `test/parity.typ` imports this
// by relative path, as it imports `fuzzy-score`.
#let _rank(rows, query, limit: none, body-search: true) = {
  // SPLIT ONCE, before the loop: a parse costs about 60 microseconds and its
  // answer cannot change between rows.
  let rpn = split-query(query).rpn
  // WHETHER THE TREE CARRIES A TEXT CLAUSE — the browse-listing question a bare
  // `q != ""` used to answer, generalised to a tree where a `tags:`-only query
  // (every atom's field is `tags`) is exactly as score-free as an empty one.
  let has-text = rpn.any(tok => tok.at(0) == "atom" and tok.at(1) != "tags")
  let name-hits = ()
  let body-hits = ()
  for e in rows {
    // `e.at("tags", default: ())` rather than `e.tags`, mirroring `row.tags ?? []`
    // in the port: this function ranks rows a CALLER supplies, including
    // `test/parity.typ`'s literal corpus, so a row with no `tags` field reads as
    // untagged rather than erroring.
    let tags = e.at("tags", default: ()).map(_fold)
    // ONE `eval-clauses` CALL PER ROW, not one per tier: a gating clause
    // (`tags:`), and a scoring clause (a bare word, or an unknown field
    // falling back to text) trying its name tier and falling to its body
    // tier, are all resolved by the SAME walk — so `window depth` can score
    // "window" in the name tier and "depth" in the body tier on one row, and
    // the row still lands in exactly one tier, per `eval-clauses`'s
    // reduction.
    //
    // SCORED AGAINST `label`, not `text`: `label` is the authored title
    // flattened, else the body's first 60 characters, else the name, so a
    // titleless note is findable by what it says rather than by its id alone.
    //
    // `e.id` JOINS `e.name`/`e.label` here — always `"idea:" + e.name`, so a
    // reader typing that literal colon (`idea:flat` for `idea:flat-ids`) still
    // subsequence-matches it, which is what makes the fallback below findable
    // rather than merely non-erroring. It rarely wins the max on its own: the
    // unmatched `"idea:"` prefix costs the near-start and length-closeness
    // bonuses `e.name` alone would earn.
    let row-eval = eval-clauses(rpn, _resolve(
      v => _best((fuzzy-score(e.name, v), fuzzy-score(e.label, v), fuzzy-score(e.at("id", default: ""), v))),
      v => body-score(e.at("body", default: ""), v),
      tags,
      body-search,
    ))
    if row-eval.matched {
      // A ROW WITH NO MATCHED TEXT CLAUSE AT ALL — a pure gating query, or an
      // empty one — carries tier `"none"` out of `eval-clauses`, which lands
      // here rather than in the body tier: that is the existing browse-listing
      // shape (see `_rank`'s own header) and the date-ordering branch below
      // depends on it.
      if row-eval.at("tier", default: "none") == "body" {
        body-hits.push((..e, score: row-eval.score, kind: "body"))
      } else {
        name-hits.push((..e, score: row-eval.score, kind: "name"))
      }
    }
  }
  // A REAL SEARCH (a tree with a text clause) sorts by score descending.
  // Otherwise: bucket into dated and undated — appending into each bucket
  // preserves the incoming id-ascending order within it — walk the dated
  // buckets' distinct stamps newest to oldest, and append the undated group
  // unchanged at the end.
  name-hits = if has-text {
    name-hits.sorted(key: e => -1 * e.score)
  } else {
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
  }
  body-hits = body-hits.sorted(key: e => -1 * e.score)
  let out = name-hits + body-hits
  if limit == none { out } else { out.slice(0, calc.min(limit, out.len())) }
}
