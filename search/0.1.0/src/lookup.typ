// `#search-ideas` — fuzzy lookup over a rookery's ids, titles and bodies, as
// data rather than as UI.
//
// It is a module of its own so that `#search-index` in `corpus.typ` can import
// the name: a module cannot import the entrypoint that imports it.

#import "@rookery/core:0.1.0": ideas
#import "base.typ": *
#import "rank.typ": *

//   #context search-ideas("flt")   // -> ((id: "idea:flat-ids", .., score: 47, kind: "name"), ..)
//   #context search-ideas("flt", body-search: false)   // ids and titles only
//   #context search-ideas("flt", tags: "phd")          // only notes tagged phd
//   #context search-ideas("tags:(a|b)&c flt")          // a reader's tag filter
//
// Returns a plain ARRAY of dictionaries — every field `@rookery/core`'s `ideas()`
// provides (id, name, title, text, label, tags, body, href, page, created) plus
// `score` and `kind` — so a caller renders it however it likes. Pure Typst: no
// rheo needed, though `href` is `none` without it, nothing else minting note
// pages, in which case a caller links with `#link(label(id))`.
//
// TWO TIERS, not one blended number. `kind: "name"` rows — matched on id or
// title, via `fuzzy-score`, taking the better of the two — sort above every
// `kind: "body"` row, matched on body text via `body-score`. A body match and a
// title match are not the same kind of evidence, and a reader looking for a note
// by name must not have it pushed below another note that mentions the word six
// times; a weighted sum would only approximate that and need retuning. `kind` is
// also what the modal's preview pane reads.
//
// A LEADING `tags:` IN THE QUERY IS A FILTER, extracted before any scoring, and
// the rest of the query is a text search over the survivors:
//
//   tags:draft window depth   notes tagged draft*, ranked by "window depth"
//   tags:draft                notes tagged draft*, no residual: the browse
//                              order — dated newest-first, undated by id
//   window depth              no `tags:` prefix, no filter
//   tags:                     the whole corpus; an empty expression is no filter
//
// The grammar is in full at `parse-tag-query` in `tagquery.typ`: `&` binds
// tighter than `|`, `()` groups, `!` negates and binds tightest, an unescaped
// SPACE ends the expression and opens the residual text, `\` escapes the next
// cluster into the current atom, and an atom matches a tag by PREFIX on the
// folded form, so `tags:note` also matches `notebook`. Parsing never fails: a
// half-typed `tags:(a|` repairs to `tags:a`.
//
// A TAG NEVER BECOMES A SEARCH TERM. Ranking matches a note's id and title, and
// its body when `body-search` is on, and nothing else — so the bare query "phd"
// finds the note CALLED that, not the notes tagged with it. Only the `tags:`
// prefix reaches tags, and it decides which notes are CANDIDATES rather than how
// they rank: narrowing the corpus and matching the query stay two separate
// things.
//
// SO THERE ARE TWO `tags:` AXES and they compose. The `tags:` PARAMETER below is
// the author's, fixed at build time and handed to `ideas()`; the `tags:` PREFIX
// in the query string is the reader's, typed into the bar. Both narrow before a
// score is computed, and a query's prefix filters within whatever the parameter
// selected.
//
// TWO SORTED PASSES CONCATENATED rather than one sort on a compound key, Typst's
// `.sorted(key:)` wanting a comparable key and an array key not reliably being
// one. Each tier is filtered out, sorted by score descending, and the two joined;
// `limit:` applies to the concatenation, not per tier. Ties stay in id order,
// `ideas()` returning id-ordered rows and Typst's sort being stable — a guarantee
// that must survive within each tier.
//
// `body-search: false` DROPS THE SECOND TIER ENTIRELY: ids and titles are
// searched, bodies are not, and no row comes back `kind: "body"`. For a rookery
// whose notes are looked up by name, full-text hits are noise — a four-word query
// lands on the note that mentions all four in passing, below the note actually
// called that. It is a judgement about the corpus, so it is a parameter rather
// than a default this package picks, and `#search-index` carries it through to
// the browser, where it also stops shipping every note's body text on every page.
//
// FULL BODIES HERE, COMPRESSED BODIES IN THE BROWSER. This path scores each
// note's whole plain-text body, while `#search-index` ships only that note's
// `body-terms` most distinctive terms and the JavaScript matches against those.
// The static Typst path is therefore exhaustive and the browser searches a
// compressed index: a note findable here by a word the compression dropped is not
// findable in the bar. Agreement would cost either every body inline on every
// page — which `_compress-corpus` exists to avoid — or blinding this path for
// symmetry.
//
// Parity is unaffected by that asymmetry: `body-score` and `bodyScore` are one
// rule, and the fixture feeds both languages the same input, pinning the rule
// rather than which caller supplies prose and which supplies a term list.
//
// `tags:`/`match:` are rookery's own pair, passed straight through to `ideas()` —
// `tags` is `none` for the whole rookery, one string, or an array of strings;
// `match` is "any" or "all". Nothing is re-filtered here and `tags-of` is
// deliberately not imported: rookery owns that predicate, and one filter written
// twice is how two copies drift. It also means an excluded note is never scored
// and never pays for its body conversion, `ideas()` filtering before its `.map`.
//
// The rows carry `tags` for free, in the author's own order and `()` when
// untagged: a row is `(..e, score: .., kind: ..)` over whatever `ideas()`
// returned, so every field rookery adds arrives here without this package naming
// it. Group or re-filter on that field with no second registry read.
//
// Must be called INSIDE a `#context` block, `ideas()` reading a `state`'s
// `.final()`. It is not itself a context function, because such a function can
// only return content and the whole point here is to return data.
#let search-ideas(
  query,
  limit: none,
  body-search: true,
  tags: none,
  match: "any",
) = {
  assert(
    type(query) == str,
    message: "@rookery/search: #search-ideas' `query` must be a string — "
      + "got " + repr(query),
  )
  assert(
    limit == none or (type(limit) == int and limit >= 0),
    message: "@rookery/search: #search-ideas' `limit` must be none or a "
      + "non-negative integer — got " + repr(limit),
  )
  _assert-bool(body-search, "body-search", "#search-ideas'")
  _assert-tags(tags, "#search-ideas'")
  _assert-match(match, "#search-ideas'")
  _rank(
    ideas(tags: tags, match: match),
    query,
    limit: limit,
    body-search: body-search,
  )
}
