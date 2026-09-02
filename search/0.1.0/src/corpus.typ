// The JSON island `#search-index` mints into a page, and the build-once cache
// that keeps the corpus pass from running once per emitted page.

#import "base.typ": *
#import "compress.typ": *
#import "lookup.typ": *

// ---- The build-once corpus cache ------------------------------------------
//
// `_compress-corpus` is a pure function of its arguments and Typst memoises it
// perfectly WITHIN one document — MEASURED natively: 20 identical calls cost
// the same 1.1s as one, whether the argument array is a reused value or rebuilt
// with `.map` on every call, inside `context` or not. None of the obvious
// suspects defeats it.
//
// Under rheo it does not collapse, and that is what this cache is for. rheo
// emits many documents from one build, and the memo does not carry across them.
// MEASURED on a synthetic rookery of 200 notes at 1500 words, 40 vertebrae, one
// `#search-modal` each:
//
//     40 vertebrae emitting the island   10.2s
//      1 vertebra  emitting the island    5.6s
//     40 vertebrae, body-search: false     1.0s
//
// so ~118ms per emitting page, against ~15ms for the island's own JSON, which
// scales the whole build by the page count on exactly the sites big enough to
// want search.
//
// `.marrow.typ` next to this file runs ONCE at the bundle root, compresses the
// whole rookery there, and publishes the result here. KEYED BY NOTE ID, not by
// position: `#search-index` selects and orders its own rows, and an id lookup
// survives both. The knobs that change the terms are in the key too, so an index
// built with different `body-terms`/`df-ceiling` never reads another's terms.
//
// EMPTY WITHOUT RHEO, which is the whole fallback: `.final()` gives `(:)`, every
// lookup misses, and `#search-index` compresses inline exactly as before. Same
// under rheo for a TAG-FILTERED index — see the miss path at its call site.
#let _corpus-cache = state("rookery-search-corpus", (:))

// The cache key for one set of compression knobs. A string rather than a dict
// so it can be a dictionary key at all.
#let _corpus-key(body-terms, df-ceiling) = "t" + str(body-terms) + "/d" + str(df-ceiling)

//
//   #search-index()                       // usually not called directly
//   #search-index(elem-id: "notes-index")  // a second, differently-keyed index
//   #search-index(body-terms: 24)          // a tighter term budget per note
//   #search-index(df-ceiling: 20)          // a harsher cut of shared terms
//   #search-index(body-search: false)      // no body text in the island at all
//   #search-index(tags: "phd")             // only the notes tagged phd
//
// Emits `<script type="application/json" id="rookery-search-index">[...]</script>`,
// one row per note: `(id, name, text, tags, body, created, href)`, where `text`
// is the plain-text title ("" when untitled), `tags` is the note's own tag
// array (THE KEY IS ABSENT when it has none), `body` is that note's compressed
// term string ("" when it compresses to nothing), `created` is that note's
// resolved date as a zero-padded `"[year][month][day]"` string (THE KEY IS
// ABSENT when the note is undated — never shipped as `""` or `null`; this is
// the same stamp `_rank` computes from `e.created` for the default/browse
// listing, see its comment), and `href` is the depth-relative
// path to the note's minted page — computed against the page this call sits on,
// so an island in a site's shared chrome comes out right on a nested vertebra
// too.
//
// The field is `text`, not `title`, on purpose: same name, same meaning, same
// type as `search-ideas` returns. `title` there is CONTENT, which JSON cannot
// carry, and one name meaning two types across two surfaces is how a consumer
// gets it wrong.
//
// `body-terms` AND `df-ceiling` CONTROL THE COMPRESSION, and there is no
// character cap any more: a row's `body` is `_compress-corpus`' output for that
// note — its `body-terms` most distinctive terms, space-joined in weight order,
// with every term appearing in more than `df-ceiling` percent of the SELECTED
// notes dropped first. The measurements behind both defaults are recorded at
// `_compress-corpus`.
//
// `body-chars` IS RETIRED, and that is 0.3.0's breaking change. The budget is a
// term count now, because a prefix cap spent the bytes on whatever a note
// happened to open with and hid the rest of it from the browser entirely —
// MEASURED, 36% of weeknotes' prose was unfindable in the bar. It is legal only
// because this field is no longer read as prose: the preview pane fetches the
// note's own page instead of excerpting the island.
//
// A cap of SOME kind is not optional, because the island is INLINE IN EVERY
// PAGE, not fetched once: MEASURED for rookery.ohrg.org, its `content/*.typ`
// sources total ~31 KB across roughly 40 notes, so an uncapped index costs on
// the order of 20-25 KB of JSON on every page.
//
// THE FIELD IS STILL CALLED `body` and still holds plain text — what changed is
// its CONTENT, not its name or its type. `search()` in
// `src/search.js` reads `hit.body` and `snippet` excerpts it for the
// failed-fetch fallback; both keep working, and the string they get simply reads
// as a keyword row rather than as a note's opening sentence.
//
// `df-ceiling` IS MEASURED OVER THE SELECTED NOTES, so `tags:` below moves it: a
// term common across a whole rookery can be distinctive within one tag's notes,
// and each island's ceiling is computed for the corpus it actually carries.
//
// A NOTE CAN COMPRESS TO NOTHING, and its `body` is then `""`. MEASURED, one note
// on weeknotes did, its body being genuinely empty. Such a note is unfindable by
// body — the same as an empty note already was — and its keyword row is empty.
//
// `body-search: false` OMITS THE `body` FIELD ALTOGETHER — a row is then
// `(id, name, text, href)`, and the island shrinks to roughly the sum of the
// corpus's ids and titles. It is the same switch `#search-ideas` takes and
// means the same thing on both sides of the language boundary: the browser
// searches ids and titles only. No JavaScript change is needed to enforce it,
// and that is by construction rather than luck — `search()` in
// `src/search.js` reads `row.body ?? ""`, and `bodyScore("", q)` is
// `null` for every non-empty query, so a row with no body simply cannot produce
// a body-tier hit. Leaving the field out is therefore the whole implementation.
//
// Two consequences worth stating plainly. A note findable ONLY by a word in its
// body becomes unfindable — that is the point, not a regression. And the modal's
// preview pane loses the keyword row drawn from this field, so on `file://`
// (where the rich preview cannot be fetched) it shows "No preview"; over http the
// fetched page is unaffected.
//
// EITHER WAY THE TYPST SIDE STAYS EXHAUSTIVE: `#search-ideas` scores full bodies
// and never truncated, so a term this island drops — to `body-search: false`, to
// the `df-ceiling`, or to the `body-terms` cut — is still findable there. See its
// comment on that deliberate asymmetry.
//
// WHY NOT A SEPARATE FETCHED JSON FILE, which would keep pages small: rheo
// emits pages from typst, and there is no supported way for a package to emit
// a standalone asset file next to them. An inline island is what the package
// can actually produce, and it also works from `file://` with no fetch.
//
// `search-bar` emits this itself, so most projects never call it. Call it
// directly when building a custom UI, or when several bars share one index —
// see `search-bar`'s `index:` parameter.
//
// The rows are `search-ideas("")` — the empty query matching everything — with
// the fields JSON cannot carry dropped, and unmintable notes filtered out. No
// `body-search:` is forwarded to that call and none is wanted: an empty query
// returns `none` from `body-score` for every note, so the body tier is empty
// whatever the switch says, and every row arrives through the name tier.
//
// `tags:`/`match:` ARE forwarded there, and they scope the island: a note the
// selection excludes is not in the JSON, so the browser cannot find it. That is
// how a bar over just the notes tagged `phd` is built — see `#search-bar`.
//
// EACH ROW CARRIES ITS NOTE'S `tags`, because the browser now has something left
// to decide with them: a reader types `tags:(a|b)&c` into the bar and the script
// evaluates that expression per row (see `#search-ideas`' comment on the two
// axes). The author's `tags:` parameter below still settles the CORPUS in Typst —
// what ships is the field the reader's own filter reads.
//
// MEASURED, 40 notes with tags present, bodies under 0.2.0's 1200-cluster prefix
// cap: 51.1 KB -> 51.8 KB, so +723 B, +1.4%, about 18 B per note. The per-note
// cost is unchanged now that the cap is a term budget; the PERCENTAGE is larger,
// the rest of the row having shrunk.
//
// THERE IS DELIBERATELY NO `tag-search: false` SWITCH. 18 B a note does not earn a
// knob — `body-search: false` earns one because it removes the largest field in
// the row, and a per-project judgement about whether full-text hits are noise has
// no counterpart here.
//
// THE KEY IS OMITTED for an untagged note rather than written as `()`, exactly as
// `body-search: false` omits `body`: an absent key means "none", where `()` would
// cost a key per row to say the same thing. The port reads `row.tags ?? []`.
#let search-index(
  elem-id: "rookery-search-index",
  body-terms: 48,
  df-ceiling: 40,
  body-search: true,
  tags: none,
  match: "any",
) = context {
  if _target() != "html" { return }
  assert(
    type(body-terms) == int and body-terms > 0,
    message: "@rookery/search: #search-index's `body-terms` must be a "
      + "positive integer — got " + repr(body-terms),
  )
  assert(
    type(df-ceiling) == int and df-ceiling >= 1 and df-ceiling <= 100,
    message: "@rookery/search: #search-index's `df-ceiling` must be an "
      + "integer between 1 and 100 — got " + repr(df-ceiling),
  )
  _assert-bool(body-search, "body-search", "#search-index's")
  _assert-tags(tags, "#search-index's")
  _assert-match(match, "#search-index's")
  let selected = search-ideas("", tags: tags, match: match).filter(e => e.href != none)
  // BODIES, NOT ROWS, and the whole reason is in `_compress-corpus`' comment:
  // this call runs on every output page and is memoised only while every argument
  // is page-invariant, which `href` is not. `e.body` is projected out here and
  // the result is zipped back on positionally below.
  let bodies = if not body-search {
    ()
  } else {
    // The bundle-root cache first (see `_corpus-cache` above). Only for an
    // UNFILTERED index: `tags:` narrows the corpus, and both the note count and
    // the document frequencies are corpus-wide, so a filtered index's terms are
    // genuinely different terms and must be computed over the notes it selected.
    // A missing id falls through the same way — a note the marrow could not see
    // (no minted page yet, no rheo at all) must not silently index as nothing.
    let cached = _corpus-cache.final().at(_corpus-key(body-terms, df-ceiling), default: (:))
    if tags == none and selected.len() > 0 and selected.all(e => e.id in cached) {
      selected.map(e => cached.at(e.id))
    } else {
      _compress-corpus(
        selected.map(e => e.body),
        body-terms: body-terms,
        df-ceiling: df-ceiling,
      )
    }
  }
  // Built by insertion rather than as one literal, so `body` can be left out
  // entirely under `body-search: false` and `tags` left out for an untagged note.
  // Leaving the KEY OUT is not the same state as an empty string, and now that a
  // note really can compress to no terms the difference carries weight: an absent
  // key means "not indexed", `""` means "indexed, and nothing distinctive
  // survived". `href` is inserted after them either way, keeping a row's field
  // order the documented one.
  //
  // THE INSERTION ORDER IS THE FIELD ORDER, and `tags` goes after `text` and
  // before `body` so that an island row reads in the same order as an `ideas()`
  // row. Nothing depends on it — JSON objects are read by key — but two shapes for
  // one record differing only in their order is how a reader diffing them wastes
  // an afternoon.
  //
  // THIS LOOP IS AFTER `_compress-corpus`, deliberately: `tags` is added to the
  // ROW, never to that call's arguments, which stay `selected.map(e => e.body)`.
  // Its memoisation is keyed on its arguments (see its comment — 287 ms for 30
  // identical calls against 6242 ms for 30 differing in one), so widening them
  // would silently multiply build time by the page count.
  let rows = selected.enumerate().map(pair => {
    let (i, e) = pair
    // `label`, NOT `text`, and the island's field name stays `text` regardless.
    //
    // `text` here means WHAT TO CALL THIS NOTE, and rookery's `label` is that
    // question's answer: the authored title flattened, else the note's first 60
    // characters of body, else its name — never empty. `e.text` is the AUTHORED
    // title alone and is `""` for a titleless note, so a note written as
    // `#idea[body]` shipped an empty title and `row.js` fell back to printing its
    // slug or its sequence number.
    //
    // THE ISLAND'S KEY IS UNCHANGED on purpose. It is a published contract a site
    // may build its own UI on, and what the field MEANS has not changed — only
    // which of rookery's two fields answers it best.
    let row = (id: e.id, name: e.name, text: e.label)
    if e.tags.len() > 0 { row.insert("tags", e.tags) }
    if body-search { row.insert("body", bodies.at(i)) }
    // Same `"[year][month][day]"` stamp `_rank`'s `stamp-of` computes from
    // `e.created` — omitted, never `""` or `none`, for an undated note, the
    // same convention `tags`/`body` above already use.
    //
    // THE ROW FIELD IS `created`, and so is the island key. Both were `updated`
    // until 0.6.0; rookery removed that field, and keeping the island key named
    // `updated` while it carried a creation date would be exactly the drift this
    // file's comments exist to prevent. `just parity` is what keeps this stamp
    // and `score.js`'s `dateCmp` reading the same key.
    let u = e.at("created", default: none)
    if u != none { row.insert("created", u.display("[year][month][day]")) }
    row.insert("href", e.href)
    row
  })
  if rows.len() == 0 { return }
  html.elem(
    "script",
    attrs: (type: "application/json", id: elem-id),
    json.encode(rows, pretty: false),
  )
}
