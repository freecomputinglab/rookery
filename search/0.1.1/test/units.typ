// Unit fixture for the pure, state-free helpers in `/src/lib.typ`.
//
// Run with `just test` from `search/0.1.1`. No runner, no JS: `assert.eq`
// fails the compile with a line number, which is the whole harness — same
// shape as `@rookery/core`'s `test/units.typ`.
//
// `--features html` is mandatory even though nothing here renders HTML —
// `std.target` is gated by the feature, and `/src/lib.typ` reads it at
// import time.

#import "/src/lib.typ": (_cached-tokens, _compress-ranked, _tokenize)

// `_cached-tokens`: the narrowed-rebuild cache decision.

// No ligaments supplied at all (an ordinary full build, or narrowing off):
// `_lig-get` would return `none`, and `_cached-tokens` must fall through to a
// fresh tokenize rather than error on `none.len()`.
#assert.eq(_cached-tokens("rheo context typst", none), _tokenize("rheo context typst"))

// Ligaments supplied, but this id was never attached before (a brand-new
// note): `_lig-get` returns `()`.
#assert.eq(_cached-tokens("rheo context typst", ()), _tokenize("rheo context typst"))

// A cache hit: the cached body is byte-identical to this compile's body, so
// the cached tokens are reused VERBATIM — even a deliberately wrong token
// list, to prove this is a reuse and not a silent re-tokenize.
#assert.eq(
  _cached-tokens("rheo context typst", ((page: "p", value: (body: "rheo context typst", tokens: ("bogus", "tokens"))),)),
  ("bogus", "tokens"),
)

// A cache miss: the cached body no longer matches (the note's own text
// changed, OR a note it references changed and the flatten picked that up) —
// falls through to a fresh tokenize of the CURRENT body, never the stale one.
#assert.eq(
  _cached-tokens("rheo context typst now", ((page: "p", value: (body: "rheo context typst", tokens: ("bogus", "tokens"))),)),
  _tokenize("rheo context typst now"),
)

// `_cached-tokens` and `_compress-ranked` together: a narrowed compile equals a full rebuild.

// A hand-built corpus standing in for `ideas()`'s rows, run through two
// paths that must agree exactly for `index.json` to agree exactly:
//
//   - "full": every body tokenized fresh, as a cold build does (no
//     ligaments supplied at all).
//   - "narrowed": one note's body changed (the live vertebra this round);
//     the rest reuse a PRIOR round's `search-row:<id>` cache, built from the
//     OLD corpus below.
//
// `_compress-ranked` is corpus-wide (document frequency, the `df-ceiling`
// cut), so this also pins that reusing SOME notes' tokens and freshly
// tokenizing others still produces the same ranked terms a full rebuild of
// the NEW corpus would, for every note — not only the changed one.
#let old-bodies = (
  "rheo context typst changes removing types html released",
  "search index rebuild ligaments typst narrowed compile",
  "waterline rookery search index typst bundle root asset",
)
#let new-bodies = (
  old-bodies.at(0),
  // Note 1 is the live vertebra this round — its body changed.
  "search index rebuild ligaments typst narrowed compile cache",
  old-bodies.at(2),
)

// What the PRIOR round attached for each id, from `old-bodies` — exactly the
// shape `.marrow.typ` writes: `(body: .., tokens: ..)` per id.
#let prior-cache = old-bodies.map(b => (body: b, tokens: _tokenize(b)))

// The narrowed round: id 1's cached body no longer matches its new body, so
// it retokenizes; ids 0 and 2 are unchanged and reuse the prior cache.
#let narrowed-toks = new-bodies.enumerate().map(((i, b)) => {
  _cached-tokens(b, (( page: "p", value: prior-cache.at(i) ),))
})
#let narrowed-terms = _compress-ranked(narrowed-toks, body-terms: 48, df-ceiling: 40)

// The ground truth: a full rebuild of the NEW corpus, no caching at all.
#let full-terms = new-bodies.map(_tokenize)
#let full-ranked = _compress-ranked(full-terms, body-terms: 48, df-ceiling: 40)

#assert.eq(narrowed-terms, full-ranked, message: "narrowed-compile terms must equal a full rebuild's")
// The unchanged notes' tokens really were reused, not coincidentally equal
// after a fresh tokenize — pin that id 0 and id 2 took the cache path.
#assert.eq(narrowed-toks.at(0), prior-cache.at(0).tokens)
#assert.eq(narrowed-toks.at(2), prior-cache.at(2).tokens)
// And id 1 (the live vertebra) did NOT reuse the stale cache.
#assert.eq(narrowed-toks.at(1), _tokenize(new-bodies.at(1)))
