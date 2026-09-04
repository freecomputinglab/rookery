// The JSON island `#search-index` mints into a page, and the build-once cache
// that keeps the corpus pass from running once per emitted page.

#import "base.typ": *
#import "compress.typ": *
#import "lookup.typ": *

// Under rheo the corpus pass cannot lean on Typst's memo: rheo emits many
// documents from one build and the memo does not carry across them, so a
// 200-note rookery with 40 emitting vertebrae paid about 118 ms a page against
// the 15 ms its own JSON costs — the whole build scaled by the page count, on
// exactly the sites big enough to want search.
//
// `.marrow.typ` next to this file runs ONCE at the bundle root, compresses the
// whole rookery there, and publishes the result into this state. KEYED BY NOTE
// ID rather than by position, `#search-index` selecting and ordering its own
// rows; the knobs that change the terms are in the key too, so an index built
// with different `body-terms`/`df-ceiling` never reads another's terms.
//
// EMPTY WITHOUT RHEO, which is the whole fallback: `.final()` gives `(:)`, every
// lookup misses, and `#search-index` compresses inline. The same happens under
// rheo for a tag-filtered index — see the miss path at its call site.
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
// resolved date as the zero-padded `"[year][month][day]"` stamp `_date-stamp`
// builds (THE KEY IS ABSENT when the note is undated — never `""` or `null`),
// and `href` is the depth-relative path to the note's minted page, computed
// against the page this call sits on, so an island in a site's shared chrome
// comes out right on a nested vertebra too.
//
// The field is `text`, not `title`, on purpose: same name, same meaning, same
// type as `search-ideas` returns. `title` there is CONTENT, which JSON cannot
// carry, and one name meaning two types across two surfaces is how a consumer
// gets it wrong.
//
// `body-terms` AND `df-ceiling` CONTROL THE COMPRESSION: a row's `body` is
// `_compress-corpus`' output for that note — its `body-terms` most distinctive
// terms, space-joined in weight order, with every term appearing in more than
// `df-ceiling` percent of the SELECTED notes dropped first. The reasoning behind
// both defaults is at `_compress-corpus`.
//
// A BUDGET IS NOT OPTIONAL, because the island is inline in EVERY page rather
// than fetched once: a 40-note rookery's sources run to about 31 KB, so an
// uncapped index would cost 20-25 KB of JSON per page. The budget is a term count
// rather than a character prefix so that the bytes go on a note's distinctive
// terms instead of on whatever it opens with — a prefix cap left about a third of
// a real corpus unfindable in the bar.
//
// `df-ceiling` IS COMPUTED OVER THE SELECTED NOTES, so `tags:` below moves it: a
// term common across a whole rookery can be distinctive within one tag's notes,
// and each island's ceiling is measured for the corpus it actually carries.
//
// A NOTE CAN COMPRESS TO NOTHING, and its `body` is then `""` — a genuinely empty
// note. It is unfindable by body, as an empty note always is, and its keyword row
// in the modal is empty.
//
// `body-search: false` OMITS THE `body` FIELD ALTOGETHER — a row is then
// `(id, name, text, href)`, and the island shrinks to roughly the sum of the
// corpus's ids and titles. It is the same switch `#search-ideas` takes and
// means the same thing on both sides of the language boundary: the browser
// searches ids and titles only, and no JavaScript enforces that: `search` in
// `src/score.js` reads `row.body ?? ""` and `bodyScore("", q)` is `null` for
// every non-empty query, so a row with no body cannot produce a body-tier hit.
// Leaving the field out is the whole implementation.
//
// Two consequences. A note findable ONLY by a word in its body becomes
// unfindable, which is the point. And the modal's preview pane loses the keyword
// row drawn from this field, so on `file://`, where the rich preview cannot be
// fetched, it shows "No preview"; over http the fetched page is unaffected.
//
// EITHER WAY THE TYPST SIDE STAYS EXHAUSTIVE: `#search-ideas` scores full bodies,
// so a term this island drops — to `body-search: false`, to the `df-ceiling`, or
// to the `body-terms` cut — is still findable there.
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
// the fields JSON cannot carry dropped and unmintable notes filtered out. No
// `body-search:` is forwarded to that call and none is wanted: an empty query
// returns `none` from `body-score` for every note, so the body tier is empty
// whatever the switch says, and every row arrives through the name tier.
//
// `tags:`/`match:` ARE forwarded there, and they scope the island: a note the
// selection excludes is not in the JSON, so the browser cannot find it. That is
// how a bar over just the notes tagged `phd` is built — see `#search-bar`.
//
// EACH ROW CARRIES ITS NOTE'S `tags`, because the browser has something to decide
// with them: a reader types `tags:(a|b)&c` into the bar and the script evaluates
// that expression per row. The author's `tags:` parameter below settles the
// CORPUS in Typst; this field is what the reader's own filter reads.
//
// It costs about 18 B a note, which is why there is no `tag-search: false`
// switch: `body-search: false` earns one by removing the largest field in the
// row, and this has no such case to answer.
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
  // Its memo is keyed on those arguments, so widening them would silently
  // multiply build time by the page count.
  let rows = selected.enumerate().map(pair => {
    let (i, e) = pair
    // `text` MEANS WHAT TO CALL THIS NOTE, and rookery's `label` is that
    // question's answer: the authored title flattened, else the note's first 60
    // characters of body, else its name — never empty. `e.text` is the authored
    // title alone and is `""` for a titleless note, which would leave the row
    // renderer printing a slug. The island's KEY stays `text`, being a published
    // contract a site may build its own UI on.
    let row = (id: e.id, name: e.name, text: e.label)
    if e.tags.len() > 0 { row.insert("tags", e.tags) }
    if body-search { row.insert("body", bodies.at(i)) }
    // The same `_date-stamp` `_rank` sorts the browse listing by, and the same key
    // name — `score.js`'s `dateCmp` reads `created`, and `just parity` keeps the
    // two honest. Omitted for an undated note rather than written as `""` or
    // `none`, the convention `tags` and `body` above also follow.
    let u = _date-stamp(e.at("created", default: none))
    if u != none { row.insert("created", u) }
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
