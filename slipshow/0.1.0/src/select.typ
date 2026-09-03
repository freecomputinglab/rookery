// Resolves a slipshow's slip list and its order, from either definition
// route — an explicit array of already-rendered ideas, or a tag query over
// the registry. Renders nothing.
//
// `ideas()` sorts its rows by id (`@rookery/core`'s `data.typ`), which is
// almost never presentation order, so the query route sorts explicitly here —
// `slip-order` (see `tags.typ`) is the default.
//
// `tags:` also accepts a PREDICATE — a function from a tag dictionary to a
// bool — as the extension point for a full boolean grammar
// (`@rookery/search`'s `a&b`) with no dependency on search: a caller builds
// the predicate itself with `eval-tag-query(parse-tag-query("a&b").rpn, ..)`
// and hands it straight to `tags:`.
//
// `where:` is the row-shaped counterpart: a predicate over the WHOLE
// registry row rather than only its tag dictionary, for a selection `tags:`
// cannot express — by `created`, `page`, `name`, `title`, or `body`. A row
// (`ideas(values: true)`, `@rookery/core`'s `data.typ`) carries `id`, `name`,
// `title`, `text`, `label`, `tags` (a flat array of key names), `tags-dict`
// (the full dictionary, values included), `body`, `href`, `page`, and
// `created`. `tags:` keeps its narrower one-argument shape — that is what
// lets `@rookery/search`'s `eval-tag-query` plug into it with no adapter —
// so a query needing a field off the row reaches for `where:` instead. The
// two compose: `tags:` runs first, since it is core's own cheap filter, and
// `where:` narrows whatever survives it.

#import "@rookery/core:0.1.0": ideas
#import "tags.typ": *
#import "marker.typ": *

// The registry rows a tag query resolves to, unsorted. Must be called INSIDE
// a `#context` block (it reads the registry via `ideas`); it is not itself a
// context function, because a context function may only return content and
// the whole point here is to return data — the same discipline `ideas()`
// itself follows.
//
// A function `tags` is the predicate route: `ideas()`'s own `tags:`/`match:`
// have no boolean operators, so a predicate instead walks every row's
// `tags-dict` itself. Otherwise `tags`/`match` pass straight to `ideas()`,
// which validates them — duplicating `_assert-tags`/`_assert-match` here
// would just be a second copy of the same message. `tags: none` still goes
// through `ideas()`, which is what makes a `where:`-only query see the whole
// corpus rather than an empty one.
//
// `where` filters the survivors by the WHOLE row, after `tags`, so its type
// is checked up front — before either `ideas()` branch runs — so a bad
// `where:` panics with this message even when the call has no surrounding
// `#context` to satisfy `ideas()`'s own registry read.
#let _slip-rows-from-query(tags, match, where) = {
  assert(
    where == none or type(where) == function,
    message: "@rookery/slipshow: `where` must be a function taking a "
      + "registry row and returning a bool — got " + repr(where),
  )
  let rows = if type(tags) == function {
    ideas(values: true).filter(r => tags(r.tags-dict))
  } else {
    ideas(tags: tags, match: match, values: true)
  }
  if where == none { rows } else { rows.filter(r => where(r)) }
}

// The four accepted `order` forms, all sorted through `_sort-pairs`:
//
//   - an ARRAY of note names/ids — sort by position in that array;
//   - `"created"` — ascending by the row's `created` field;
//   - `"slip-order"` (the default) — ascending by the note's `slip-order` tag;
//   - a FUNCTION — ascending by `order(row)`, over the WHOLE row (the same
//     shape `where:` sees), so a deck can be ordered by title, priority,
//     page, body length, a computed score, or any composite of those.
//
// A key function and not a comparator, because Typst has no comparator
// anywhere: `array.sorted` takes only `key:`. `reverse:` is how descending
// order is reached.
//
// Every form treats "no key" — an unmatched array position, no `created`, no
// `slip-order` tag, a key function returning `none` — the same way: that row
// sorts LAST, in id order, regardless of `reverse`. `reverse` therefore
// reverses only the KEYED rows: an undated note is not "first" in a
// reverse-chronological deck, it is still the note with no date.
#let _sort-pairs(pairs, reverse) = {
  // Sort the keyed rows by a COMPOUND key — the real key, then the row's
  // `id` — rather than relying on `.sorted()`'s stability: a tie keeps id
  // order, a reader can check that directly, and the build stays
  // reproducible whatever Typst's sort does with equal keys.
  let keyed = pairs
    .filter(p => p.key != none)
    .sorted(key: p => (p.key, p.row.id))
    .map(p => p.row)
  if reverse { keyed = keyed.rev() }
  keyed + pairs.filter(p => p.key == none).map(p => p.row).sorted(key: row => row.id)
}

#let _sort-rows(rows, order, reverse) = {
  if type(order) == array {
    // Position in `order`, matched against either `name` or `id` so a caller
    // may write whichever form is at hand; a row named nowhere in `order`
    // is unkeyed (`position` already returns `none`), which keeps unnamed
    // rows after every named one and in their incoming (id) order among
    // themselves.
    _sort-pairs(
      rows.map(row => (key: order.position(n => n == row.name or n == row.id), row: row)),
      reverse,
    )
  } else if order == "created" {
    // `[year][month][day]` and no time fields: `display()` errors on a field
    // the datetime was not constructed with, and this shape sorts in date
    // order as a plain string.
    _sort-pairs(
      rows.map(row => (
        key: if row.created == none { none } else { row.created.display("[year][month][day]") },
        row: row,
      )),
      reverse,
    )
  } else if order == "slip-order" {
    _sort-pairs(rows.map(row => (key: order-of(row.tags-dict), row: row)), reverse)
  } else if type(order) == function {
    // Call the key function ONCE per row — an author's key function may walk
    // the note's body — and keep the pair `(key, row)`, rather than sorting a
    // single compound key that folds `none`-ness into it: Typst cannot
    // compare values of different types, so a `.sorted()` over a mix of
    // `none` and a real key would error out rather than merely order oddly.
    // Partitioning on `none` (in `_sort-pairs`) makes that mixed comparison
    // impossible instead of merely unlikely.
    let pairs = rows.map(row => (key: order(row), row: row))
    let kinds = pairs.map(p => p.key).filter(k => k != none).map(type).dedup()
    assert(
      kinds.len() <= 1,
      message: "@rookery/slipshow: `order`'s key function must return the same "
        + "type for every note — got " + kinds.map(repr).join(" and ")
        + ". Typst cannot compare values of different types.",
    )
    if kinds.len() == 1 {
      assert(
        kinds.at(0) in (int, float, str, datetime),
        message: "@rookery/slipshow: `order`'s key function must return an "
          + "int, float, str, or datetime — got " + repr(kinds.at(0))
          + ". `r.title` is content and cannot be compared this way — use a "
          + "string field like `r.label` or `r.text` instead.",
      )
    }
    _sort-pairs(pairs, reverse)
  } else {
    panic(
      "@rookery/slipshow: `order` must be an array of note names/ids, "
        + "\"created\", \"slip-order\" (the default), or a function from a "
        + "registry row to a comparable value — got " + repr(order),
    )
  }
}

// Resolves a slipshow's slip list, from either definition route:
//
//   #context resolve-slips(tags: "slip")                    // a tag query
//   #context resolve-slips(where: r => r.page == "methods")  // a row query
//   resolve-slips(slips: (slip("a")[..], slip("b")[..]))     // an explicit array
//
// The two routes return differently shaped entries on purpose — a `"content"`
// entry is rendered inline, a `"row"` entry via `#window` — so the renderer
// needs no key-presence guessing to tell them apart:
//
//   (kind: "content", content: <item>, tags: <dict>)   // from `slips:`
//   (kind: "row", row: <ideas() row>, tags: <dict>)     // from `tags:`/`where:`
//
// The query route needs `#context` (it calls `ideas()` through
// `_slip-rows-from-query`); `slips:` does not, since it only reads tags back
// out of content already in hand. `tags:` and `where:` compose — both may be
// given together — but `slips:` is exclusive with either, since an explicit
// array has nothing left to filter. `order:`/`reverse:` sort the query
// route's rows (see `_sort-rows`); both are refused alongside `slips:` for
// the same reason.
#let resolve-slips(
  slips: none,
  tags: none,
  where: none,
  match: "any",
  order: "slip-order",
  reverse: false,
) = {
  assert(
    type(reverse) == bool,
    message: "@rookery/slipshow: `reverse` must be a bool — got " + repr(reverse),
  )
  let slips-given = slips != none
  let query-given = tags != none or where != none
  assert(
    slips-given != query-given,
    message: "@rookery/slipshow: resolve-slips needs exactly one of `slips`, "
      + "`tags`, or `where` — got "
      + (if slips == none and tags == none and where == none {
        "none of them"
      } else {
        "`slips` together with `tags`/`where`, which conflict"
      })
      + ". Pass `slips:` for an explicit ordered array of ideas, or `tags:` "
      + "and/or `where:` to query the registry.",
  )

  if slips != none {
    assert(
      type(slips) == array,
      message: "@rookery/slipshow: `slips` must be an array of already-rendered "
        + "ideas — got " + repr(slips),
    )
    // An explicit array is already ordered by construction; re-sorting it (or
    // reversing that order) would be surprising, so `order:`/`reverse:` are
    // refused rather than silently ignored.
    assert(
      order == "slip-order",
      message: "@rookery/slipshow: `order` and `slips:` conflict — an explicit "
        + "array is already in the order it was written, so `order:` has "
        + "nothing to do. Drop `order:`, or use `tags:` instead of `slips:`.",
    )
    assert(
      reverse == false,
      message: "@rookery/slipshow: `reverse` and `slips:` conflict — an explicit "
        + "array is already in the order it was written, so `reverse:` has "
        + "nothing to do. Drop `reverse:`, or use `tags:` instead of `slips:`.",
    )
    return slips.map(item => (kind: "content", content: item, tags: slip-tags-of(item)))
  }

  let rows = _sort-rows(_slip-rows-from-query(tags, match, where), order, reverse)
  rows.map(row => (kind: "row", row: row, tags: row.tags-dict))
}
