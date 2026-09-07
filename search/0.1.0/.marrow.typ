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
//   - `_corpus-cache`, the compressed body terms keyed by note id, read back
//     by `#search-index(mode: "inline")` — the `file://` mode, which cannot
//     fetch and so must still carry the island in every page.
//
// WITHOUT RHEO there is no bundle root, this file never runs, no asset is
// emitted, `_corpus-cache` keeps its `(:)` default and `#search-index`
// compresses inline as it always did. A miss there is only slower, never
// different; a missing asset is why `mode: "asset"` needs rheo at all.
#import "@rookery/search:0.1.0": (
  _compress-corpus, _corpus-cache, _corpus-key, _date-stamp, _index-asset-path,
)
#import "@rookery/core:0.1.0": ideas

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
    let terms = _compress-corpus(
      rows.map(e => e.body),
      body-terms: body-terms,
      df-ceiling: df-ceiling,
    )
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
  }
}
