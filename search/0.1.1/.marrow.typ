// Builds the rookery's search index ONCE per build, at the bundle root, and
// emits it as a single fetched asset.
//
// rheo inlines this file verbatim at the bundle root when a project imports
// `@rookery/search`, so it runs once for the whole build with the finished
// note registry in scope — the same place `@rookery/core`'s own `.marrow.typ`
// mints note pages from. Two things come out of that one pass:
//
//   - `rookery/search/index.json`, the whole index as a bundle asset, which
//     `#search-index(mode: "asset")` points every page at instead of carrying
//     a copy of it. This is what keeps a large rookery's build from scaling
//     the index by the page count: MEASURED on a 320-note, 360-page site,
//     29.5s and 43MB of output against 2.3s and 4.9MB.
//   - `_rows-cache` and `_corpus-cache`, for `#search-index(mode: "inline")` —
//     the `file://` mode, which cannot fetch and so must still carry the island
//     in every page. The first holds the finished rows so no page derives them
//     again (26.0s to 17.7s on that same site); the second holds the compressed
//     body terms alone, and is what a `tags:`-filtered or non-default-knobbed
//     index still falls back to.
//
// WITHOUT RHEO there is no bundle root, this file never runs, no asset is
// emitted, `_corpus-cache` keeps its `(:)` default and `#search-index`
// compresses inline as it always did. A miss there is only slower, never
// different; a missing asset is why `mode: "asset"` needs rheo at all.
#import "@rookery/search:0.1.1": (
  _cached-tokens, _compress-ranked, _corpus-cache, _corpus-key, _date-stamp,
  _index-asset-path, _rows-cache,
)
#import "@rookery/core:0.1.1": (ideas, _attach, _join-content, _lig-get)

// This package's own ligament key, same vocabulary rules as
// `@rookery/core`'s (`state.typ`'s `_LIG-*` banner): `search-row:<id>`, one
// per note, carrying this build's compressed terms for that note AND the
// plain-text `body` they were compressed from. `page:` is the row's own
// `origin` (the OWNING VERTEBRA), never this file's own — bundle-root marrow
// code has no page of its own to attach under.
//
// WHY A ROW CARRIES ITS OWN `body` ALONGSIDE `tokens`: `_tokenize` is a pure
// function of a note's body alone, so this cache is sound ONLY while the
// cached body still matches what `ideas()` returns for that id THIS compile
// — and a note's body is not purely a function of its own raw text: it is
// flattened against the WHOLE corpus's resolved titles (`_ref-text`, data.typ),
// so a note that references another note whose title changed gets a
// DIFFERENT body even though nothing in `rec.origin == id`'s own vertebra
// moved. Comparing the actual materialized body string — not a `page:
// matches the round's live vertebra` guess — catches that case for free: a
// mismatch retokenizes, a match reuses. See the LIGAMENTS banner below for
// why no cheaper, still-correct signal exists.
#let _LIG-SEARCH-ROW = "search-row:"

#context {
  // `page`, not `href`: `#note-path` is the site-root-relative output path and
  // is defined exactly when a note has a minted page, which is the same
  // condition `#search-index`'s own `href != none` filter tests from a
  // vertebra. `href` is depth-relative and has no meaning at the bundle root,
  // where there is no current page to measure from.
  let rows = ideas().filter(e => e.page != none)
  if rows.len() > 0 {
    // The DEFAULTS only. A project calling `#search-index(body-terms: 64)` gets
    // a key miss and compresses inline — correct, just not cached. Publishing
    // every combination a project might ask for would mean reading the call
    // sites' arguments back out of a state the marrow itself feeds, and a state
    // that depends on a state fed from the pages it feeds is the one shape
    // Typst's convergence cannot be trusted to settle.
    let body-terms = 48
    let df-ceiling = 40

    // LIGAMENTS — the whole optimization this cache exists for: skip
    // RE-TOKENIZING a note whose body this compile produces byte-identical
    // to the one `search-row:<id>` cached last time it was attached. The
    // df/tf-idf WEIGHTING below still runs over every note's tokens every
    // compile (`_compress-ranked`, corpus-wide by construction — a changed
    // note's terms can shift another note's document frequency, so that
    // pass cannot be narrowed without risking a different index.json for an
    // unrelated note). Only the regex-driven tokenize pass, which is a pure
    // function of one note's own body, is skippable this way.
    //
    // `_lig-get` returns `none` on an ordinary full build (no ligaments
    // supplied at all) or `()` on a narrowed compile where this id was never
    // attached before (a brand-new note) — both fall through to a fresh
    // `_tokenize`, exactly a full build's own behaviour.
    let toks = rows.map(row => _cached-tokens(row.body, _lig-get(_LIG-SEARCH-ROW + row.id)))
    let terms = _compress-ranked(toks, body-terms: body-terms, df-ceiling: df-ceiling)

    // Re-attach every row's body and tokens under its own id, for the NEXT
    // compile to read back. A row with no `origin` (no rheo compile, or a
    // minted artifact with no owning vertebra) is skipped — there is no page
    // to attribute the attach to, same guard `_idea-ligaments` applies.
    _join-content(rows.enumerate().map(((i, row)) => {
      if row.origin == none { return [] }
      _attach(_LIG-SEARCH-ROW + row.id, (body: row.body, tokens: toks.at(i)), page: row.origin)
    }))

    let by-id = (:)
    for (i, e) in rows.enumerate() { by-id.insert(e.id, terms.at(i)) }
    _corpus-cache.update(c => {
      let c = c
      c.insert(_corpus-key(body-terms, df-ceiling), by-id)
      c
    })

    // THE ASSET'S ROWS ARE `_rank`'s EMPTY-QUERY ORDER, reproduced here rather
    // than borrowed: `#search-index` used to get this order by calling
    // `search-ideas("")` per page, and the browser is entitled to the same
    // sequence from the fetched file. `fuzzy-score` returns 0 for an empty
    // query, so every note ties in the name tier and the tie breaks by date —
    // dated notes newest first, undated notes last in id order (`ideas()`
    // sorts by id, and each `.filter` below preserves that). See `_rank` in
    // `src/rank.typ` for the same three steps on the per-page path.
    let stamped = rows.enumerate().map(pair => {
      let (i, e) = pair
      (
        id: e.id,
        name: e.name,
        text: e.label,
        tags: e.tags,
        body: terms.at(i),
        created: _date-stamp(e.at("created", default: none)),
        page: e.page,
      )
    })
    let dated = stamped.filter(r => r.created != none)
    let undated = stamped.filter(r => r.created == none)
    let ordered = ()
    for s in dated.map(r => r.created).dedup().sorted().rev() {
      ordered += dated.filter(r => r.created == s)
    }

    // `href` CARRIES THE SITE-ROOT PATH here, where the per-page island's
    // carries a depth-relative one: one shared file cannot hold a path
    // measured from each of 360 pages. `src/island.js` joins each row's
    // `href` onto the `data-rookery-search-base` prefix the page it was
    // fetched from published. The field keeps its name so nothing downstream
    // of the fetch has to know which mode produced it.
    //
    // The remaining field rules are `#search-index`'s and are asserted by
    // `test/`: `tags` omitted when the note has none, `created` omitted when
    // it is undated, `body` always present (the asset is `body-search: true`
    // by construction — a page wanting no body tier drops the field on read
    // rather than fetching a second file for it).
    let final-rows = (ordered + undated).map(r => {
      let row = (id: r.id, name: r.name, text: r.text)
      if r.tags.len() > 0 { row.insert("tags", r.tags) }
      row.insert("body", r.body)
      if r.created != none { row.insert("created", r.created) }
      row.insert("href", r.page)
      row
    })
    asset(_index-asset-path, json.encode(final-rows, pretty: false))

    // THE SAME ROWS, published for `mode: "inline"` to read back. Kept with
    // `page` rather than the asset's finished `href` because an inline island's
    // href is measured from the page it sits in, which only that page knows —
    // see `_rows-cache`. `body` is always present and `body-search: false`
    // drops it on read, so one row set serves both switches.
    _rows-cache.update(c => {
      let c = c
      c.insert(_corpus-key(body-terms, df-ceiling), ordered + undated)
      c
    })
  }
}
